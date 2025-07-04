//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
@testable import OctopusCore

class NotificationsTests: XCTestCase {
    private var injector: Injector!
    private var mockProfileRepository: MockProfileRepository!
    private var mockNotificationService: MockNotificationService!
    private var mockNetworkMonitor: MockNetworkMonitor!
    private var mockAppStateMonitor: MockAppStateMonitor!
    private var mockUserNotifCenter: MockUserNotificationCenterProvider!
    private var postsFeedManager: FeedManager<Post>!
    private var storage = [AnyCancellable]()

    override func setUp() {
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { NotificationsDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .authProvider, .networkMonitor, .blockedUserIdsProvider,
                               .userProfileFetchMonitor, .appStateMonitor)
        injector.register { _ in MockProfileRepository() }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { NotificationSettingsDatabase(injector: $0) }
        mockUserNotifCenter = MockUserNotificationCenterProvider()
        injector.register { _ in self.mockUserNotifCenter }

        mockProfileRepository = (injector.getInjected(identifiedBy: Injected.profileRepository) as! MockProfileRepository)
        mockNotificationService = (injector.getInjected(identifiedBy: Injected.remoteClient)
            .notificationService as! MockNotificationService)
        mockNetworkMonitor = (injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor)
        mockAppStateMonitor = (injector.getInjected(identifiedBy: Injected.appStateMonitor) as! MockAppStateMonitor)

        postsFeedManager = PostsFeedManager.mockFactory(injector: injector)
    }

    func testSetNotificationDeviceToken() async throws {
        let notificationsRepository = NotificationsRepository(injector: injector)
        // Set no connectivity
        mockNetworkMonitor.connectionAvailable = false

        // Since there is no connectivity and no profile yet, calling set(notificationDeviceToken:) shouldn't do anything
        notificationsRepository.set(notificationDeviceToken: "token")

        // Set connectivity. This should trigger sending the token
        mockNotificationService.injectNextRegisterPushToken(Com_Octopuscommunity_RegisterPushTokenResponse())
        mockNetworkMonitor.connectionAvailable = true
        try await assertWithTimeout(mockNotificationService.registerPushTokenResponses.isEmpty)

        // Mock a profile is present. This should trigger sending the token
        mockNotificationService.injectNextRegisterPushToken(Com_Octopuscommunity_RegisterPushTokenResponse())
        mockProfileRepository.profile = createProfile(id: "profile1", userId: "user1", nickname: "User1")
        try await assertWithTimeout(mockNotificationService.registerPushTokenResponses.isEmpty)

        // Ensure that connectivity loss and regain do not send token again
        mockNetworkMonitor.connectionAvailable = false
        mockNetworkMonitor.connectionAvailable = true
        try await delay()

        // Ensure that whenever the user id changes, it sends again the token
        mockNotificationService.injectNextRegisterPushToken(Com_Octopuscommunity_RegisterPushTokenResponse())
        mockProfileRepository.profile = createProfile(id: "profile2", userId: "user2", nickname: "User2")
        try await assertWithTimeout(mockNotificationService.registerPushTokenResponses.isEmpty)

        // ensure that the token is not sent again if the user id does not change
        mockProfileRepository.profile = createProfile(id: "profile3", userId: "user2", nickname: "Nick")
        try await delay()

        // ensure that the token is sent immediatly if there is a user and internet connectivity
        mockNotificationService.injectNextRegisterPushToken(Com_Octopuscommunity_RegisterPushTokenResponse())
        notificationsRepository.set(notificationDeviceToken: "token")
        try await assertWithTimeout(mockNotificationService.registerPushTokenResponses.isEmpty)

        // ensure token is sent again when user logs out
        mockNotificationService.injectNextRegisterPushToken(Com_Octopuscommunity_RegisterPushTokenResponse())
        mockProfileRepository.profile = nil
        try await assertWithTimeout(mockNotificationService.registerPushTokenResponses.isEmpty)
    }

    func testCanHandlePushNotifications() async throws {
        // Precondition: Notif token has never been set (this info is kept in the UserDefaults)
        UserDefaults.standard.set(nil, forKey: "OctopusSDK.Notifications.DeviceTokenSetOnce")
        UserDefaults.standard.synchronize()
        var notificationsRepository = NotificationsRepository(injector: injector)

        // initial value should be false
        XCTAssertFalse(notificationsRepository.canHandlePushNotifications)

        // set the permission to authorized. It should not have any impact on canHandlePushNotifications because token
        // is not set yet
        mockAppStateMonitor.appState = .background
        mockUserNotifCenter.mockAutorizationStatus(.authorized)
        mockAppStateMonitor.appState = .active
        try await delay() // add a delay to be sure that the value STAYS at false
        XCTAssertFalse(notificationsRepository.canHandlePushNotifications)

        notificationsRepository.set(notificationDeviceToken: "token")
        try await assertWithTimeout(notificationsRepository.canHandlePushNotifications)

        mockAppStateMonitor.appState = .background
        mockUserNotifCenter.mockAutorizationStatus(.denied)
        mockAppStateMonitor.appState = .active
        try await assertWithTimeout(!notificationsRepository.canHandlePushNotifications)

        // re-create the NotificationRepository to be sure that the DeviceTokenSetOnce is correctly stored
        notificationsRepository = NotificationsRepository(injector: injector)

        // initial value should be false
        XCTAssertFalse(notificationsRepository.canHandlePushNotifications)

        // set the permission to authorized. It should not have any impact on canHandlePushNotifications because token
        // is not set yet
        mockAppStateMonitor.appState = .background
        mockUserNotifCenter.mockAutorizationStatus(.provisional)
        mockAppStateMonitor.appState = .active
        try await assertWithTimeout(notificationsRepository.canHandlePushNotifications)

        mockAppStateMonitor.appState = .background
        mockUserNotifCenter.mockAutorizationStatus(.denied)
        mockAppStateMonitor.appState = .active
        try await assertWithTimeout(!notificationsRepository.canHandlePushNotifications)
    }

    private func createProfile(id: String, userId: String, nickname: String) -> CurrentUserProfile {
        CurrentUserProfile(
            id: id, userId: userId, nickname: nickname, email: nil, bio: nil, pictureUrl: nil,
            notificationBadgeCount: 0, blockedProfileIds: [],
            newestFirstPostsFeed: Feed(id: "", feedManager: postsFeedManager))
    }
}

/// A mock profile repository that provides a profile. This profile can be set using `profile`.
private class MockProfileRepository: ProfileRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.profileRepository

    @Published public var profile: CurrentUserProfile?
    var profilePublisher: AnyPublisher<CurrentUserProfile?, Never> { $profile.eraseToAnyPublisher() }
    @Published private(set) var hasLoadedProfile: Bool = true // default is true on this implem
    var hasLoadedProfilePublisher: AnyPublisher<Bool, Never> { $hasLoadedProfile.eraseToAnyPublisher() }

    var onCurrentUserProfileUpdated: AnyPublisher<Void, Never> {
        Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    func fetchCurrentUserProfile() async throws(AuthenticatedActionError) { }

    func createCurrentUserProfile(with profile: EditableProfile) async throws(UpdateProfile.Error)
    -> (CurrentUserProfile, Data?) {
        fatalError("Not implemented")
    }

    func updateCurrentUserProfile(with profile: EditableProfile) async throws(UpdateProfile.Error)
    -> (CurrentUserProfile, Data?) {
        fatalError("Not implemented")
    }

    func deleteCurrentUserProfile(profileId: String) async throws {
        fatalError("Not implemented")
    }

    func resetNotificationBadgeCount() async throws {
        fatalError("Not implemented")
    }

    func getProfile(profileId: String) -> AnyPublisher<OctopusCore.Profile?, any Error> {
        fatalError("Not implemented")
    }

    func fetchProfile(profileId: String) async throws(OctopusCore.ServerCallError) {
        fatalError("Not implemented")
    }

    func blockUser(profileId: String) async throws(OctopusCore.AuthenticatedActionError) {
        fatalError("Not implemented")
    }
}

/// Extension to PostsFeedManager that provides a factory for a mock implementation
private extension PostsFeedManager {
    static func mockFactory(injector: Injector) -> FeedManager<Post> {
        return FeedManager<Post>(
            injector: injector,
            feedItemDatabase: MockPostItemDatabase(),
            getOptions: .all,
            mapper: { _, _, _ in
                return nil
            })
    }

    private class MockPostItemDatabase: FeedItemsDatabase {
        typealias FeedItem = Post

        func getMissingFeedItems(infos: [FeedItemInfo]) async throws -> [String] {
            fatalError("Not implemented")
        }

        func getFeedItems(ids: [String]) async throws -> [Post] {
            fatalError("Not implemented")
        }

        func feedItemsPublisher(ids: [String]) throws -> AnyPublisher<[Post], any Error> {
            fatalError("Not implemented")
        }

        func upsert(feedItems: [Post]) async throws { }

        func deleteAll(except ids: [String]) async throws { }
    }
}
