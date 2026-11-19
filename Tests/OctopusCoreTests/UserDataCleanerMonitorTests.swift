//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import CoreData
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

class UserDataCleanerMonitorTests: XCTestCase {
    /// Cleared by the cleaning, which makes it observable.
    private let clientUserPictureKey = "OctopusSDK.client.user.picture"
    /// Stands for the device being unlocked or the app coming back.
    private let sessionReadTrigger = PassthroughSubject<Void, Never>()

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: clientUserPictureKey)
        super.tearDown()
    }

    func testLogoutRemovesCachedContent() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "first-user", jwtToken: "test-token"))
        try await seedCachedContent(in: injector)
        let postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        try await MainActor.run {
            let cachedPost = try XCTUnwrap(postsDatabase.getPostOnMainThread(id: "cached-post"))
            XCTAssertTrue(cachedPost.permissions.canAccess)
            XCTAssertFalse(cachedPost.permissions.canCreateChildren)
        }

        let postLoaded = expectation(description: "The cached post is observed")
        // the publisher may emit the post more than once before the logout
        postLoaded.assertForOverFulfill = false
        let postRemoved = expectation(description: "Logout removes the observed post")
        let subscription = postsDatabase.postPublisher(uuid: "cached-post").sink { post in
            if post != nil {
                postLoaded.fulfill()
            } else {
                postRemoved.fulfill()
            }
        }
        defer { subscription.cancel() }
        await fulfillment(of: [postLoaded], timeout: 5)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: nil)
        await fulfillment(of: [postRemoved], timeout: 5)

        try await assertCachedContentIsEmpty(in: injector)
        try await assertWithTimeout {
            try await MainActor.run { try postsDatabase.getPostOnMainThread(id: "cached-post") == nil }
        }

        userDataStorage.store(userData: .init(id: "next-user", jwtToken: "next-test-token"))
        try await assertCachedContentIsEmpty(in: injector)
        try await MainActor.run {
            XCTAssertNil(try postsDatabase.getPostOnMainThread(id: "cached-post"))
        }
    }

    /// The user config lives in its own store: its deletion must be saved there, or the previous user's community
    /// access gate carries over to the next session.
    func testLogoutRemovesTheUserConfigFromItsStore() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "first-user", jwtToken: "test-token"))
        let userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        try await userConfigDatabase.upsert(canAccessCommunity: false, message: "No access")
        let storedConfigCount = try await userConfigCountInStore(in: injector)
        XCTAssertEqual(storedConfigCount, 1)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: nil)

        try await assertWithTimeout { try await self.userConfigCountInStore(in: injector) == 0 }
    }

    /// The next session's access gate, written right after the logout, survives the purge.
    func testUserConfigWrittenRightAfterTheLogoutIsKept() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "first-user", jwtToken: "test-token"))
        let userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        try await userConfigDatabase.upsert(canAccessCommunity: false, message: "No access")

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: nil)
        try await userConfigDatabase.upsert(canAccessCommunity: true, message: nil)
        // leave time for a late deletion to happen if the purge were not queued first
        try await Task.sleep(nanoseconds: 300_000_000)

        let storedAccess = try await userConfigAccessInStore(in: injector)
        XCTAssertEqual(storedAccess, [true])
    }

    func testAClientUserReplacedByAnotherIsCleaned() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "first-user", clientId: "first-client", jwtToken: "test-token"))
        try await seedCachedContent(in: injector)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: .init(id: "next-user", clientId: "next-client", jwtToken: "next-token"))

        try await assertWithTimeout { try await self.cachedContentCount(in: injector) == 0 }
        try await assertCachedContentIsEmpty(in: injector)
    }

    /// A member whose account was deleted comes back with a new account, under the same client user: what the
    /// deleted account left, its denied access included, goes.
    func testADeletedAccountReplacedByANewAccountOfTheSameClientUserIsCleaned() async throws {
        try await assertReplacingADeletedAccountCleans(
            by: .init(id: "new-user", clientId: "client", jwtToken: "new-token"))
    }

    func testADeletedAccountReplacedByAGuestIsCleaned() async throws {
        try await assertReplacingADeletedAccountCleans(by: .init(id: "guest-user", jwtToken: "guest-token"))
    }

    private func assertReplacingADeletedAccountCleans(by newSession: UserDataStorage.UserData,
                                                      file: StaticString = #filePath, line: UInt = #line)
    async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "deleted-user", clientId: "client", jwtToken: "test-token"))
        try await seedCachedContent(in: injector)
        try await injector.getInjected(identifiedBy: Injected.userConfigDatabase).upsert(
            UserConfig(canAccessCommunity: false, accessDeniedMessage: "Bye", noAccessReason: .accountDeleted))

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: newSession)

        try await assertWithTimeout { try await self.cachedContentCount(in: injector) == 0 }
        try await assertCachedContentIsEmpty(in: injector)
        try await assertWithTimeout { try await self.userConfigCountInStore(in: injector) == 0 }
    }

    /// A guest only has what any guest can see: becoming a client user keeps it, as does a refreshed token.
    func testAGuestBecomingAClientUserOrARefreshedTokenKeepsTheContent() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))
        try await seedCachedContent(in: injector)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: .init(id: "client-user", clientId: "client", jwtToken: "test-token"))
        userDataStorage.store(userData: .init(id: "client-user", clientId: "client", jwtToken: "refreshed-token"))
        // leave time for a cleaning to happen if one were triggered
        try await Task.sleep(nanoseconds: 300_000_000)

        let contentCount = try await cachedContentCount(in: injector)
        XCTAssertEqual(contentCount, 5)
    }

    /// The purge is queued before the logout returns: what the next session writes right after survives it.
    func testContentWrittenRightAfterTheLogoutIsKept() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "first-user", jwtToken: "test-token"))
        try await seedCachedContent(in: injector)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: nil)
        try await referenceInAFeed(ids: ["next-session-post"], in: injector)
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        try await context.performAsync {
            let post = PostEntity(context: context)
            post.uuid = "next-session-post"
            post.parentId = "parent"
            post.text = "Fetched by the next session"
            post.statusValue = StorableStatus.published.rawValue
            post.statusReasonCodes = ""
            post.statusReasonMessages = ""
            try context.save()
        }

        let postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        let posts = try await postsDatabase.getPosts(ids: ["cached-post", "next-session-post"])
        XCTAssertEqual(posts.map(\.uuid), ["next-session-post"])
    }

    func testLogoutAsksTheScreensToReload() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "first-user", jwtToken: "test-token"))
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let contentCleared = expectation(description: "The screens are asked to reload")
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        userDataStorage.store(userData: nil)

        await fulfillment(of: [contentCleared], timeout: 5)
    }

    /// The closure of the community deleted the cached content, and the session kept through it does not change at
    /// reopening: the reopening itself asks the screens to load again.
    func testAReopeningWithASessionAsksTheScreensToReload() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "member", jwtToken: "test-token"))
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        let contentCleared = expectation(description: "The screens are asked to reload")
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }

        monitor.reloadAfterCommunityReopening()

        await fulfillment(of: [contentCleared], timeout: 5)
    }

    /// Without a session, the guest connected at reopening is a session that appears, which asks for the reload: the
    /// reopening does not ask for it a second time.
    func testAReopeningWithoutASessionLeavesTheReloadToTheSessionThatAppears() async throws {
        let injector = makeInjector()
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        let contentCleared = expectation(description: "The screens are not asked to reload")
        contentCleared.isInverted = true
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }

        monitor.reloadAfterCommunityReopening()

        await fulfillment(of: [contentCleared], timeout: 0.5)
    }

    /// A community switch stops the cleaner before it logs out, so that nothing of the community being left loads
    /// again: a reopening seen during the switch does not ask for that reload either.
    func testAReopeningOnceStoppedDoesNotAskTheScreensToReload() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "member", jwtToken: "test-token"))
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        monitor.stop()
        let contentCleared = expectation(description: "The screens are not asked to reload")
        contentCleared.isInverted = true
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }

        monitor.reloadAfterCommunityReopening()

        await fulfillment(of: [contentCleared], timeout: 0.5)
    }

    /// After a logout or a community switch the screens load while there is no session yet, and what they get is
    /// the anonymous content. The session that comes next (a guest, then the member) must load it again.
    func testASessionAppearingAfterNoneAsksTheScreensToReload() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        // launched without a session: nothing on screen was loaded for one, so nothing reloads yet
        let contentCleared = expectation(description: "The screens are asked to reload")
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }

        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))

        await fulfillment(of: [contentCleared], timeout: 5)
    }

    /// A logout reloads what is on screen right away, with no session, so that the purged feeds do not stay empty if
    /// no session comes, then again with the guest that is connected after it.
    func testALogoutFollowedByAGuestReloadsOnceForEach() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "member", clientId: "client", jwtToken: "token"))
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let contentCleared = expectation(description: "The screens are asked to reload")
        contentCleared.expectedFulfillmentCount = 2
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: nil)
        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))

        await fulfillment(of: [contentCleared], timeout: 5)
    }

    /// The root feeds fetched without a session are the anonymous ones (their ids name no user): the main feed
    /// stays the anonymous one unless they are fetched again once the session is there.
    func testASessionAppearingAfterNoneFetchesTheRootFeedsAgain() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        let feedService = injector.getInjected(identifiedBy: Injected.remoteClient).feedService as! MockFeedService
        feedService.injectNextGetRootFeedsInfo(.with {
            $0.feedsInfo = [.with {
                $0.id = "guest-feed"
                $0.label = "Feed"
            }]
        })
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))

        let rootFeedsDatabase = injector.getInjected(identifiedBy: Injected.rootFeedsDatabase)
        let rootFeedsFetched = expectation(description: "The root feeds are fetched for the session")
        // the publisher may emit the stored root feeds more than once
        rootFeedsFetched.assertForOverFulfill = false
        let subscription = rootFeedsDatabase.rootFeedsPublisher().sink { rootFeeds in
            if rootFeeds.map(\.feedId) == ["guest-feed"] { rootFeedsFetched.fulfill() }
        }
        defer { subscription.cancel() }
        await fulfillment(of: [rootFeedsFetched], timeout: 5)
    }

    /// The topics fetched without a session miss the groups the session can see: the posts of those groups would
    /// name none.
    func testASessionAppearingAfterNoneFetchesTheTopicsAgain() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        let octoService = injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService
        octoService.injectNextGetTopicsResponse(.init())
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))

        try await assertWithTimeout(octoService.getTopicsCallCount == 1)
    }

    /// At a launch with a stored session, or when the token of the session is refreshed, what is on screen was
    /// already loaded for that session.
    func testAStoredSessionAndItsRefreshedTokenDoNotReload() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "member", clientId: "client", jwtToken: "token"))
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let contentCleared = expectation(description: "The screens are asked to reload")
        contentCleared.isInverted = true
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: .init(id: "member", clientId: "client", jwtToken: "refreshed-token"))

        await fulfillment(of: [contentCleared], timeout: 0.5)
        let octoService = injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService
        XCTAssertEqual(octoService.getTopicsCallCount, 0)
    }

    /// A guest connecting as a member is the usual sign-in: a session was already there, and what is on screen was
    /// loaded for it. Only the root feeds are fetched again (`testAGuestBecomingAClientUserFetchesTheRootFeedsAgain`),
    /// not the whole screen.
    func testAGuestBecomingAClientUserDoesNotReload() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))
        let sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let contentCleared = expectation(description: "The screens are asked to reload")
        contentCleared.isInverted = true
        let subscription = sdkEventsEmitter.internalEvents.sink { event in
            if case .userContentCleared = event { contentCleared.fulfill() }
        }
        defer { subscription.cancel() }
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: .init(id: "member", clientId: "client", jwtToken: "token"))

        await fulfillment(of: [contentCleared], timeout: 0.5)
        let octoService = injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService
        XCTAssertEqual(octoService.getTopicsCallCount, 0)
    }

    /// The root feed ids name the user they were fetched for: the member who signs in must get their own, or the main
    /// feed stays the guest's until the next launch.
    func testAGuestBecomingAClientUserFetchesTheRootFeedsAgain() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))
        let feedService = injector.getInjected(identifiedBy: Injected.remoteClient).feedService as! MockFeedService
        feedService.injectNextGetRootFeedsInfo(.with {
            $0.feedsInfo = [.with {
                $0.id = "member-feed"
                $0.label = "Feed"
            }]
        })
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: .init(id: "member", clientId: "client", jwtToken: "token"))

        let rootFeedsDatabase = injector.getInjected(identifiedBy: Injected.rootFeedsDatabase)
        let rootFeedsFetched = expectation(description: "The root feeds are fetched for the member")
        // the publisher may emit the stored root feeds more than once
        rootFeedsFetched.assertForOverFulfill = false
        let subscription = rootFeedsDatabase.rootFeedsPublisher().sink { rootFeeds in
            if rootFeeds.map(\.feedId) == ["member-feed"] { rootFeedsFetched.fulfill() }
        }
        defer { subscription.cancel() }
        await fulfillment(of: [rootFeedsFetched], timeout: 5)
    }

    /// A refreshed token, before or after the sign-in, is the same session: its root feeds are already the right ones.
    func testARefreshedTokenDoesNotFetchTheRootFeedsAgain() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "guest", jwtToken: "guest-token"))
        let feedService = injector.getInjected(identifiedBy: Injected.remoteClient).feedService as! MockFeedService
        feedService.injectNextGetRootFeedsInfo(.init())
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: .init(id: "guest", jwtToken: "refreshed-guest-token"))
        userDataStorage.store(userData: .init(id: "member", clientId: "client", jwtToken: "token"))
        try await assertWithTimeout(feedService.getRootFeedsInfoCallCount == 1)
        userDataStorage.store(userData: .init(id: "member", clientId: "client", jwtToken: "refreshed-token"))
        // leave time for a fetch to happen if one were triggered
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(feedService.getRootFeedsInfoCallCount, 1)
    }

    /// A guest can become a client user under the same user id: the client id alone tells the sessions apart.
    func testAGuestBecomingAClientUserUnderTheSameIdFetchesTheRootFeedsAgain() async throws {
        let injector = makeInjector()
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "user", jwtToken: "guest-token"))
        let feedService = injector.getInjected(identifiedBy: Injected.remoteClient).feedService as! MockFeedService
        feedService.injectNextGetRootFeedsInfo(.init())
        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }

        userDataStorage.store(userData: .init(id: "user", clientId: "client", jwtToken: "member-token"))

        try await assertWithTimeout(feedService.getRootFeedsInfoCallCount == 1)
    }

    func testForceCleanRemovesCachedContentAndCanBeRepeated() async throws {
        let injector = makeInjector()
        try await seedCachedContent(in: injector)
        let monitor = UserDataCleanerMonitor(injector: injector)

        try await monitor.forceClean()
        try await assertCachedContentIsEmpty(in: injector)
        try await monitor.forceClean()
        try await assertCachedContentIsEmpty(in: injector)
    }

    /// Before the device's first unlock after a reboot the session cannot be read: that is not a logout, and the
    /// user's data must survive it. Once the session can be read, an absent one is cleaned as before.
    func testAnUnreadableSessionIsNotCleanedAsALogout() async throws {
        let injector = makeInjector()
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        UserDefaults.standard.set(Data([1]), forKey: clientUserPictureKey)
        try await seedCachedContent(in: injector)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        // leave time for a cleaning to happen if it were not waiting
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: clientUserPictureKey))
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        let contentCount = try await context.performAsync { try context.count(for: OctoObjectEntity.fetchAllGeneric()) }
        XCTAssertEqual(contentCount, 5)

        // the device is unlocked, and there turns out to be no stored session
        securedStorage.readError = nil
        sessionReadTrigger.send()

        try await assertWithTimeout(UserDefaults.standard.data(forKey: clientUserPictureKey) == nil)
        try await assertWithTimeout {
            try await context.performAsync { try context.count(for: OctoObjectEntity.fetchAllGeneric()) == 0 }
        }
        try await assertCachedContentIsEmpty(in: injector)
    }

    /// A session stored before the reboot that becomes readable on unlock is the user's: nothing is cleaned.
    func testAStoredSessionReadOnUnlockIsNotCleaned() async throws {
        let injector = makeInjector()
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        try securedStorage.set("userId", key: "user_id")
        try securedStorage.set("jwt", key: "user_jwtToken")
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        UserDefaults.standard.set(Data([1]), forKey: clientUserPictureKey)
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        try await seedCachedContent(in: injector)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        securedStorage.readError = nil
        sessionReadTrigger.send()
        XCTAssertNotNil(userDataStorage.userData)
        // leave time for a cleaning to happen if one were triggered
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertNotNil(UserDefaults.standard.data(forKey: clientUserPictureKey))
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        let contentCount = try await context.performAsync { try context.count(for: OctoObjectEntity.fetchAllGeneric()) }
        XCTAssertEqual(contentCount, 5)
    }

    private func seedCachedContent(in injector: Injector) async throws {
        try await referenceInAFeed(ids: ["cached-post", "cached-comment", "cached-reply"], in: injector)
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        try await context.performAsync {
            let post = PostEntity(context: context)
            post.text = "Cached post"
            let comment = CommentEntity(context: context)
            comment.text = "Cached comment"
            let reply = ReplyEntity(context: context)
            reply.text = "Cached reply"
            let topic = TopicEntity(context: context)
            topic.name = "Cached group"
            topic.desc = "Cached group description"
            let section = SectionEntity(context: context)
            section.name = "Cached section"

            let contents: [OctoObjectEntity] = [post, comment, reply, topic, section]
            for (content, id) in zip(contents,
                                     ["cached-post", "cached-comment", "cached-reply", "cached-topic", "cached-section"]) {
                content.uuid = id
                content.parentId = "parent"
                content.statusValue = StorableStatus.published.rawValue
                content.statusReasonCodes = ""
                content.statusReasonMessages = ""
                content.canAccessOptional = NSNumber(value: true)
                content.canCreateChildrenOptional = NSNumber(value: false)
                content.userReactionId = "reaction"
                content.userReactionKind = "👍"
                content.userPollVoteId = "vote"
            }
            topic.canAccessOptional = NSNumber(value: false)

            let media = MediaEntity(context: context)
            media.url = URL(string: "https://example.com/cached-image.png")!
            post.mediasRelationship = NSOrderedSet(array: [media])
            let option = PollOptionEntity(context: context)
            option.uuid = "option"
            option.text = "Cached poll option"
            post.pollOptionsRelationship = NSOrderedSet(array: [option])
            try context.save()
        }
    }

    /// The feeds delete the content none of them lists when they start, as the monitor's dependencies make them do.
    private func referenceInAFeed(ids: [String], in injector: Injector) async throws {
        let feedItemInfosDatabase = injector.getInjected(identifiedBy: Injected.feedItemInfosDatabase)
        try await feedItemInfosDatabase.upsert(
            feedItemInfos: ids.map { FeedItemInfo(feedId: "feed", itemId: $0, updateDate: Date(), featuredChildId: nil) },
            feedId: "feed")
    }

    private func cachedContentCount(in injector: Injector) async throws -> Int {
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        return try await context.performAsync { try context.count(for: OctoObjectEntity.fetchAllGeneric()) }
    }

    /// Counted through a fresh context on the config store: only what was saved there.
    private func userConfigCountInStore(in injector: Injector) async throws -> Int {
        let configContext = injector.getInjected(identifiedBy: Injected.configCoreDataStack).saveContext
        let freshContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        freshContext.persistentStoreCoordinator = configContext.persistentStoreCoordinator
        return try await freshContext.performAsync { try freshContext.count(for: UserConfigEntity.fetch()) }
    }

    private func userConfigAccessInStore(in injector: Injector) async throws -> [Bool?] {
        let configContext = injector.getInjected(identifiedBy: Injected.configCoreDataStack).saveContext
        let freshContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        freshContext.persistentStoreCoordinator = configContext.persistentStoreCoordinator
        return try await freshContext.performAsync {
            try freshContext.fetch(UserConfigEntity.fetch()).map(\.canAccessCommunity)
        }
    }

    private func assertCachedContentIsEmpty(in injector: Injector) async throws {
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        let counts = try await context.performAsync {
            try ["OctoObject", "Media", "PollOption"].map {
                try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: $0))
            }
        }
        XCTAssertEqual(counts, [0, 0, 0])
        let postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        let posts = try await postsDatabase.getPosts(ids: ["cached-post"])
        XCTAssertTrue(posts.isEmpty)
    }

    private func makeInjector() -> Injector {
        let injector = Injector()
        let sessionReadTrigger = sessionReadTrigger
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .authProvider, .configRepository,
                               .appStateMonitor, .blockedUserIdsProvider)
        injector.register {
            UserDataStorage(injector: $0, sessionReadTriggers: sessionReadTrigger.eraseToAnyPublisher())
        }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { NotificationsDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { TopicsDatabase(injector: $0) }
        injector.register { TopicsRepository(injector: $0) }
        injector.register { RootFeedsDatabase(injector: $0) }
        injector.register { RootFeedsRepository(injector: $0) }
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        return injector
    }
}
