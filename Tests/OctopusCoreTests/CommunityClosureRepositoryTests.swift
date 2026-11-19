//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import CoreData
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// Once the config says the community is closed, the SDK blocks every call, empties what it cached and shows the
/// closure message; it opens again when the config no longer says so.
@Suite(.serialized)
struct CommunityClosureRepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let userDefaults = UserDefaults(suiteName: "CommunityClosureRepositoryTests-\(UUID())")!

    @Test func aClosingConfigClosesBlocksAndShowsTheMessage() async throws {
        let (injector, spy) = makeInjector()
        let repository = makeRepository(injector: injector)

        await repository.handle(config: closedConfig(message: "Closed msg"), now: now)

        #expect(repository.isClosed)
        #expect(mockRemoteClient(injector).callsBlocked)
        #expect(spy.count == 1)
        #expect(repository.closure?.message == "Closed msg")
        // The access row keeps the open community's access: the closure message is shown over it while closed.
        #expect(try await storedUserConfig(injector) == nil)
    }

    @Test func theRealPurgeKeepsTheSessionAndTheProfileWithAZeroBadge() async throws {
        let (injector, _) = makeInjector(realPurger: true)
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userDataStorage.store(userData: .init(id: "userId", clientId: "clientId", jwtToken: "token"))
        userDataStorage.store(clientUserData: .init(id: "clientId"))
        try await seedContent(injector)
        let repository = makeRepository(injector: injector)

        await repository.handle(config: closedConfig(message: "Closed msg"), now: now)

        #expect(try await count(entityName: "OctoObject", in: injector) == 0)
        #expect(try await injector.getInjected(identifiedBy: Injected.eventsDatabase).getAllEvents().isEmpty)
        #expect(try await currentProfileBadgeCount(injector) == 0)
        #expect(userDataStorage.userData?.id == "userId")
        #expect(userDataStorage.userData?.jwtToken == "token")
        #expect(userDataStorage.clientUserData?.id == "clientId")
    }

    @Test func aStillClosedConfigUpdatesTheDateWithoutPurgingAgain() async throws {
        let (injector, spy) = makeInjector()
        let repository = makeRepository(injector: injector)
        let laterDate = now.addingTimeInterval(7_200)

        await repository.handle(config: closedConfig(message: "First"), now: now)
        await repository.handle(config: closedConfig(message: "Second", nextCheckAt: laterDate), now: now)

        #expect(spy.count == 1)
        #expect(repository.closure?.nextCheckDate == laterDate)
        #expect(repository.closure?.message == "Second")
    }

    @Test func anOpenConfigReopens() async throws {
        let (injector, _) = makeInjector()
        let repository = makeRepository(injector: injector)
        await repository.handle(config: closedConfig(message: "Closed msg"), now: now)

        await repository.handle(config: Com_Octopuscommunity_ApiKeyConfig(), now: now)

        #expect(!repository.isClosed)
        #expect(!mockRemoteClient(injector).callsBlocked)
        #expect(CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults).closure == nil)
    }

    /// Calls are blocked before anything can send one: at init, from what was stored by a previous launch.
    @Test func aStoredClosureBlocksCallsAtInit() {
        let (injector, _) = makeInjector()
        CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults)
            .set(CommunityClosure(kind: .closed, message: "Closed msg", nextCheckDate: now.addingTimeInterval(60)))

        let repository = makeRepository(injector: injector)

        #expect(repository.isClosed)
        #expect(mockRemoteClient(injector).callsBlocked)
        #expect(!repository.isCheckDue(now: now))
        #expect(repository.isCheckDue(now: now.addingTimeInterval(60)))
    }

    // MARK: Interrupted purge

    /// The closure is stored before its purge ends: an app killed meanwhile would show what was left until the
    /// community reopens. The next launch purges again.
    @Test func aPurgeInterruptedByAKillIsDoneAgainAtTheNextLaunch() async throws {
        let (injector, spy) = makeInjector()
        let store = CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults)
        store.set(CommunityClosure(kind: .closed, message: "Closed msg", nextCheckDate: now.addingTimeInterval(60)))
        store.set(purgePending: true)

        let repository = makeRepository(injector: injector)

        try await expectWithTimeout(spy.count == 1)
        try await expectWithTimeout(!CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults).isPurgePending)
        withExtendedLifetime(repository) { }
    }

    @Test func aCompletedPurgeIsNotDoneAgainAtTheNextLaunch() async throws {
        let (injector, spy) = makeInjector()
        await makeRepository(injector: injector).handle(config: closedConfig(message: "Closed msg"), now: now)
        #expect(spy.count == 1)

        let repository = makeRepository(injector: injector)

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        #expect(spy.count == 1)
        withExtendedLifetime(repository) { }
    }

    @Test func aFailedPurgeIsDoneAgainAtTheNextCheck() async throws {
        let (injector, spy) = makeInjector()
        spy.failures = 1
        let repository = makeRepository(injector: injector)
        await repository.handle(config: closedConfig(message: "Closed msg"), now: now)
        #expect(CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults).isPurgePending)

        await repository.handle(config: closedConfig(message: "Closed msg"), now: now)

        #expect(spy.count == 2)
        #expect(!CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults).isPurgePending)
    }

    /// Once open again, what the closure did not delete is the community's own content: nothing to purge.
    @Test func reopeningForgetsAPendingPurge() async throws {
        let (injector, spy) = makeInjector()
        spy.failures = 1
        let repository = makeRepository(injector: injector)
        await repository.handle(config: closedConfig(message: "Closed msg"), now: now)

        await repository.handle(config: Com_Octopuscommunity_ApiKeyConfig(), now: now)

        #expect(!CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults).isPurgePending)
    }

    // MARK: Helpers

    /// Locked: the purge resumed at init runs from a task.
    private final class SpyPurger: CommunityClosurePurger, InjectableObject, @unchecked Sendable {
        static let injectedIdentifier = Injected.communityClosurePurger
        private let lock = NSLock()
        private var _count = 0
        private var _failures = 0
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _count
        }
        /// How many of the next purges fail.
        var failures: Int {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _failures
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _failures = newValue
            }
        }

        func purge() async throws {
            if countAndFail() { throw MockError("Purge failed") }
        }

        /// Counts the purge and tells whether it fails, under the lock: an `async` function cannot hold an `NSLock`.
        private func countAndFail() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            _count += 1
            guard _failures > 0 else { return false }
            _failures -= 1
            return true
        }
    }

    private func makeRepository(injector: Injector) -> CommunityClosureRepository {
        CommunityClosureRepository(injector: injector,
                                   store: CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults))
    }

    private func makeInjector(realPurger: Bool = false) -> (Injector, SpyPurger) {
        let injector = Injector()
        let spy = SpyPurger()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { _ in try! TrackingCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .authProvider, .configRepository,
                               .appStateMonitor, .blockedUserIdsProvider)
        injector.register { UserDataStorage(injector: $0) }
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
        injector.register { RootFeedsDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { EventsDatabase(injector: $0) }
        if realPurger {
            injector.register { CommunityClosurePurgerDefault(injector: $0) }
        } else {
            injector.register { _ in spy }
        }
        return (injector, spy)
    }

    private func mockRemoteClient(_ injector: Injector) -> MockRemoteClient {
        injector.getInjected(identifiedBy: Injected.remoteClient) as! MockRemoteClient
    }

    private func closedConfig(message: String, nextCheckAt: Date? = nil) -> Com_Octopuscommunity_ApiKeyConfig {
        var config = Com_Octopuscommunity_ApiKeyConfig()
        config.closed = .with {
            $0.message = message
            $0.nextCheckAt = UInt64((nextCheckAt ?? now.addingTimeInterval(3_600)).timeIntervalSince1970 * 1000)
        }
        return config
    }

    private func storedUserConfig(_ injector: Injector) async throws -> UserConfig? {
        let context = injector.getInjected(identifiedBy: Injected.configCoreDataStack).saveContext
        return try await context.performAsync {
            try context.fetch(UserConfigEntity.fetch()).first.flatMap(UserConfig.init(from:))
        }
    }

    private func count(entityName: String, in injector: Injector) async throws -> Int {
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        return try await context.performAsync {
            try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: entityName))
        }
    }

    /// `nil` when the profile is gone.
    private func currentProfileBadgeCount(_ injector: Injector) async throws -> Int? {
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        return try await context.performAsync {
            try context.fetch(PrivateProfileEntity.fetchById(id: "profileId")).first
                .map { Int($0.notificationBadgeCount) }
        }
    }

    private func seedContent(_ injector: Injector) async throws {
        try await injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase).upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: false,
                                                notificationBadgeCount: 3,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        let context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        try await context.performAsync {
            let post = PostEntity(context: context)
            post.uuid = "cached-post"
            post.text = "Cached post"
            let topic = TopicEntity(context: context)
            topic.uuid = "cached-topic"
            topic.name = "Cached group"
            topic.desc = "Cached group description"
            for content in [post, topic] as [OctoObjectEntity] {
                content.parentId = "parent"
                content.statusValue = StorableStatus.published.rawValue
                content.statusReasonCodes = ""
                content.statusReasonMessages = ""
            }
            try context.save()
        }
        try await injector.getInjected(identifiedBy: Injected.eventsDatabase).upsert(event: Event(
            date: now, appSessionId: nil, uiSessionId: nil, content: .custom(CustomEvent(name: "event"))))
    }
}
