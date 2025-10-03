import Foundation
import Combine
import UserNotifications
import OctopusCore
import OctopusDependencyInjection
import os

/// Octopus Community main model object.
/// This object holds a reference on all the repositories.
public class OctopusSDK: ObservableObject {
    
    /// Number of notifications from the notification center (i.e. internal notifications) that have not been seen yet.
    /// Always 0 if the user is not connected to Octopus Community.
    @Published public private(set) var notSeenNotificationsCount: Int = 0

    /// List of topics. You can use that list to match a given topic name with a topic id.
    /// You can update the list with the latest backend values by calling `fetchTopics()`.
    /// Even if you do not call `fetchTopics()`, the update might be done internally by the SDK at any time.
    @Published public private(set) var topics: [Topic] = []

    /// Published value that indicates whether the current user has access to the community features.
    ///
    /// This respects both the SDK's internal A/B test configuration and any status set via `overrideCommunityAccess`.
    /// It is `true` when the user can access community features, `false` otherwise.
    @Published public private(set) var hasAccessToCommunity: Bool = false

    /// The block that will be called when a user taps on the bridge post button to display the client object
    public private(set) var displayClientObjectCallback: ((String) throws -> Void)?

    /// Core interface. This object should not be used by external devs, it is only used by the UI lib
    public let core: OctopusSDKCore
    private let injector: Injector

    private var storage = [AnyCancellable]()

    /// Constructor of the `OctopusSDK`.
    ///
    /// It is recommended to start this object as soon as possible.
    ///
    /// - Parameters:
    ///   - apiKey: the API key that identifies your community
    ///   - connectionMode: the kind of connection to handle the user
    public init(apiKey: String, connectionMode: ConnectionMode = .octopus(deepLink: nil)) throws {
        self.injector = Injector()
        core = try OctopusSDKCore(apiKey: apiKey, connectionMode: connectionMode.coreValue, injector: injector)

        core.profileRepository.profilePublisher
            .sink { [unowned self] in
                let newNotSeenNotificationsCount = $0?.notificationBadgeCount ?? 0
                guard notSeenNotificationsCount != newNotSeenNotificationsCount else { return }
                notSeenNotificationsCount = newNotSeenNotificationsCount
            }.store(in: &storage)

        core.topicsRepository.$topics
            .sink { [unowned self] in
                topics = $0.map { Topic(from: $0) }
            }
            .store(in: &storage)

        core.configRepository.userConfigPublisher
            .sink { [unowned self] in
                let newValue = $0?.canAccessCommunity ?? false
                guard newValue != hasAccessToCommunity else { return }
                hasAccessToCommunity = newValue
            }
            .store(in: &storage)
    }
}

// MARK: - SSO User Connection
extension OctopusSDK {
    /// Connect a user.
    ///
    /// This will make your user connected to the community. If your user does not have a community account, it will be
    /// asked to create one (pre-filled with the information you provide in `user`) when it will attempt to do an
    /// action that requires a profile (create a post, like, comment, report...).
    ///
    /// Call this function as soon as your user is connected inside your app.
    ///
    /// - Note: This function should only be called when connectionMode is `.sso`.
    /// - Parameters:
    ///   - user: the user currently connected in your app.
    ///   - tokenProvider: a block called when the user token is needed to authenticate the user on the Octopus SDK
    ///                    side. When receiving this callback, you should get a token for this user asynchronously and
    ///                    pass this token to the sub closure.
    ///
    ///  Example:
    ///  ```
    ///  connectUser(currentUser, tokenProvider: { in
    ///      let userToken = try await server.getUserTokenForOctopusSDK(clientId: currentUser.id)
    ///      return userToken
    ///  })
    ///  ```
    public func connectUser(_ user: ClientUser, tokenProvider: @Sendable @escaping () async throws -> String) {
        let connectionRepository = core.connectionRepository
        Task {
            do {
                try await connectionRepository.connectUser(user.coreValue, tokenProvider: tokenProvider)
            } catch {
                if #available(iOS 14, *) { Logger.connection.debug("Error while trying to connect client user token: \(error)") }
            }
        }
    }

    /// Disconnect the current user.
    ///
    /// Call this function when your user is disconnected.
    ///
    /// - Note: This function should only be called when connectionMode is `.sso`.
    public func disconnectUser() {
        let connectionRepository = core.connectionRepository
        Task {
            do {
                try await connectionRepository.disconnectUser()
            } catch {
                if #available(iOS 14, *) { Logger.connection.debug("Error while trying to disconnect client user token: \(error)") }
            }
        }
    }
}

// MARK: - Notification Center
extension OctopusSDK {
    /// Asks to update the `notSeenNotificationsCount`. This will fetch the information from the server.
    /// Shortly after the function finishes, the `notSeenNotificationsCount` will publish an update if there is a new
    /// value.
    public func updateNotSeenNotificationsCount() async throws {
        try await core.profileRepository.fetchCurrentUserProfile()
    }
}

// MARK: - Push Notifications
extension OctopusSDK {
    /// Pass the notification device token to the SDK.
    /// As soon as the system gives you the device token in the
    /// `UNUserNotificationCenterDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` function,
    /// you should pass it to the Octopus SDK.
    /// - Parameter notificationDeviceToken: the received device token
    public func set(notificationDeviceToken: String) {
        core.notificationsRepository.set(notificationDeviceToken: notificationDeviceToken)
    }

    /// Gets whether this notification has been triggered by an Octopus Community content.
    /// If this function returns true, it means that your app should display the Octopus UI and pass the
    /// NotificationResponse to the Octopus SDK UI.
    /// - Parameter notification: the notification to test
    /// - Returns: true if the notification is an Octopus Community one
    public static func isAnOctopusNotification(notification: UNNotification) -> Bool {
        NotificationsRepository.isAnOctopusNotification(notification: notification)
    }
}

// MARK: - A/B Testing
extension OctopusSDK {
    /// Sets whether access to the Octopus community is enabled or not (analytics only).
    ///
    /// This method is typically used when the host app manages its own A/B testing logic.
    /// It tells the Octopus backend whether the user has access to community features,
    /// but it does **not** actually grant or restrict access within the SDK itself.
    /// Instead, this information is only recorded internally for analytics and tracking,
    /// to better understand engagement patterns across test groups.
    ///
    /// - When to use:
    ///   Call this if your app is running its own A/B test and you want Octopus to
    ///   log whether a given user is in the "community-enabled" or "control" group.
    ///   This is useful for reporting and engagement analytics, but does not change
    ///   the SDK’s runtime behavior.
    ///
    /// - Parameter hasAccessToCommunity: `true` if the user is part of a group with access
    ///                                   to the community (per the host app’s A/B test),
    ///                                   `false` otherwise (e.g., control group).
    ///
    /// - See also: ``overrideCommunityAccess(_:)``
    @available(*, deprecated, renamed: "track(hasAccessToCommunity:)", message: "This function has been renamed track(hasAccessToCommunity:).")
    public func set(hasAccessToCommunity: Bool) {
        core.trackingRepository.set(hasAccessToCommunity: hasAccessToCommunity)
    }

    /// Sets whether access to the Octopus community is enabled or not (analytics only).
    ///
    /// This method is typically used when the host app manages its own A/B testing logic.
    /// It tells the Octopus backend whether the user has access to community features,
    /// but it does **not** actually grant or restrict access within the SDK itself.
    /// Instead, this information is only recorded internally for analytics and tracking,
    /// to better understand engagement patterns across test groups.
    ///
    /// - When to use:
    ///   Call this if your app is running its own A/B test and you want Octopus to
    ///   log whether a given user is in the "community-enabled" or "control" group.
    ///   This is useful for reporting and engagement analytics, but does not change
    ///   the SDK’s runtime behavior.
    ///
    /// - Parameter hasAccessToCommunity: `true` if the user is part of a group with access
    ///                                   to the community (per the host app’s A/B test),
    ///                                   `false` otherwise (e.g., control group).
    ///
    /// - See also: ``overrideCommunityAccess(_:)``
    public func track(hasAccessToCommunity: Bool) {
        core.trackingRepository.set(hasAccessToCommunity: hasAccessToCommunity)
    }

    /// Overrides the community access status managed by Octopus.
    ///
    /// This method bypasses both the SDK’s internal A/B test configuration **and** any
    /// status previously set via ``track(hasAccessToCommunity:)``. It explicitly determines
    /// whether the user can access the community features, and takes **full precedence**
    /// over all other access control mechanisms.
    ///
    /// - When to use:
    ///   Call this if you want Octopus to control access to the community directly,
    ///   instead of (or in addition to) managing A/B test groups in your own app.
    ///   Use this method when you need to guarantee that the user’s community access
    ///   is enforced by Octopus, regardless of analytics-only settings or internal
    ///   A/B testing rules.
    ///
    /// - Parameter access: `true` to grant access to the community, `false` to block it.
    /// - Throws: An error if the access override cannot be applied.
    ///
    /// - See also: ``track(hasAccessToCommunity:)``
    public func overrideCommunityAccess(_ access: Bool) async throws {
        try await core.configRepository.overrideCommunityAccess(access)
    }
}

// MARK: - Analytics
extension OctopusSDK {    
    /// Add a custom event.
    ///
    /// This event can be integrated to the analytics reports we can deliver to you.
    ///
    /// - Parameter customEvent: the custom event
    public func track(customEvent: CustomEvent) async throws {
        try await core.trackingRepository.track(customEvent: customEvent.coreValue)
    }
}

// MARK: Bridge
extension OctopusSDK {
    /// Gets the Octopus post id related to the given object id.
    ///
    /// If the Octopus post does not exist yet, it will be created. The content will only be used if the post does not
    /// exist yet.
    ///
    /// This function is asynchrounous and may take some time, if it is called after a user interaction, you should
    /// display a loader.
    /// - Parameter content: the content of the post
    /// - Returns: the Octopus post id
    /// - Note: You can use the returned id to display the post using `OctopusHomeScreen(octopus:postId:)`
    public func getOrCreateClientObjectRelatedPostId(content: ClientPost) async throws(ClientPostError) -> String {
        do {
            return try await core.postsRepository.getOrCreateClientObjectRelatedPostId(content: content.coreValue)
        } catch {
            throw ClientPostError(from: error)
        }
    }
    
    /// Set the callback that will be called when a user taps on the `backToObjectButton` that is displayed on a post
    /// related to an client object (article, product...).
    /// - Parameters:
    ///   - displayClientObjectCallback: the callback that will be called when a user taps on the `backToObjectButton`
    ///   that is displayed on a post related to an client object (article, product...). The parameter of the callback
    ///   is the object id you set when creating the post. If the block throws an error, the SDK will display an alert
    ///   to the user.
    public func set(displayClientObjectCallback: @escaping (String) throws -> Void) {
        self.displayClientObjectCallback = displayClientObjectCallback
    }
    
    /// Fetches the topics from the backend values
    /// - Note: Even if you do not call `fetchTopics()`, the update might be done internally by the SDK at any time.
    public func fetchTopics() async throws {
        try await core.topicsRepository.fetchTopics()
    }
}
