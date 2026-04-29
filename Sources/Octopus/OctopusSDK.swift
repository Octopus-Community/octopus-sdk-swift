//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import UserNotifications
import OctopusCore
import OctopusDependencyInjection
import os

/// Octopus Community main model object.
/// This object holds a reference on all the repositories.
public final class OctopusSDK: ObservableObject {

    /// Number of notifications from the notification center (i.e. internal notifications) that have not been seen yet.
    /// Always 0 if the user is not connected to Octopus Community.
    @Published public private(set) var notSeenNotificationsCount: Int = 0

    /// List of groups. You can use that list to match a given group name with a group id.
    /// You can update the list with the latest backend values by calling `fetchGroups()`.
    /// Even if you do not call `fetchGroups()`, the update might be done internally by the SDK at any time.
    @Published public private(set) var groups: [OctopusGroup] = []

    /// List of topics.
    @available(*, deprecated, renamed: "groups")
    public var topics: [OctopusGroup] { groups }

    /// Published value that indicates whether the current user has access to the community features.
    ///
    /// This respects both the SDK's internal A/B test configuration and any status set via `overrideCommunityAccess`.
    /// It is `true` when the user can access community features, `false` otherwise.
    @Published public private(set) var hasAccessToCommunity: Bool = false

    /// Event publisher.
    /// This publisher emits an event each time the user do something particular.
    /// - See `OctopusEvent` to have an full list of all events that can be emitted.
    ///
    /// If you have your own tracking service, you can use this publisher to listen to events that occured inside the
    /// Octopus UI part and feed your tracking service with them.
    ///
    /// Listen to this publisher with:
    /// ```
    /// octopus.eventPublisher.sink { event in
    ///     switch event {
    ///         ...
    ///     }
    /// }
    /// ```
    public var eventPublisher: AnyPublisher<OctopusEvent, Never> { _eventPublisher.eraseToAnyPublisher() }

    /// The block that will be called when a user taps on the bridge post button to display the client object
    public private(set) var displayClientObjectCallback: ((String) throws -> Void)?

    /// The block that will be called when a user tries to open a link inside the community.
    /// This link can come from a Post/Comment/Reply or when tapping on a Post with CTA button.
    /// If this callback returns `.handledByApp`, it means that the app has handled the URL itself,
    /// hence the Octopus SDK won't do anything more.
    /// If it is `handledByOctopus`, the URL will be opened by the Octopus SDK using `UIApplication.shared.open(URL)`.
    public private(set) var onNavigateToURLCallback: ((URL) -> URLOpeningStrategy)?

#if swift(>=5.9)
    /// Core interface. This object should not be used by external devs, it is only used by the UI lib
    package private(set) var core: OctopusSDKCore
#else
    /// Core interface. This object should not be used by external devs, it is only used by the UI lib
    public private(set) var core: OctopusSDKCore
#endif

    private var injector: Injector
    private let _eventPublisher = PassthroughSubject<OctopusEvent, Never>()
    private var storage = [AnyCancellable]()

    /// Constructor of the `OctopusSDK`.
    ///
    /// It is recommended to start this object as soon as possible.
    ///
    /// - Parameters:
    ///   - apiKey: the API key that identifies your community
    ///   - connectionMode: the kind of connection to handle the user. Default is Octopus connection mode.
    ///   - configuration: the sdk configuration. Default is default configuration.
    public init(
        apiKey: String,
        connectionMode: ConnectionMode = .octopus(deepLink: nil),
        configuration: Configuration = .init()
    ) throws {
        self.injector = Injector()
        core = try OctopusSDKCore(apiKey: apiKey,
                                  connectionMode: connectionMode.coreValue,
                                  sdkConfig: configuration.coreValue,
                                  injector: injector)

        registerPublishers()
    }

    private func registerPublishers() {
        core.sdkEventsEmitter.events
            .sink { [unowned self] in
                self._eventPublisher.send(.init(from: $0))
            }.store(in: &storage)

        core.profileRepository.profilePublisher
            .sink { [unowned self] in
                let newNotSeenNotificationsCount = $0?.notificationBadgeCount ?? 0
                guard notSeenNotificationsCount != newNotSeenNotificationsCount else { return }
                notSeenNotificationsCount = newNotSeenNotificationsCount
            }.store(in: &storage)

        core.topicsRepository.$topics
            .sink { [unowned self] in
                groups = $0.map { OctopusGroup(from: $0) }
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
    /// Call this function as soon as your user is connected inside your app and each time its profile changes in your
    /// app.
    ///
    /// - Note: This function should only be called when connectionMode is `.sso`.
    /// - Parameters:
    ///   - user: the user currently connected in your app.
    ///   - tokenProvider: a block called when the user token is needed to authenticate the user on the Octopus SDK
    ///                    side. When receiving this callback, you should get a token for this user asynchronously and
    ///                    pass this token to the sub closure.
    /// - Throws: A ``OctopusConnectUserError`` if the connection fails.
    ///
    ///  Example:
    ///  ```
    ///  try await connectUser(currentUser, tokenProvider: {
    ///      let userToken = try await server.getUserTokenForOctopusSDK(clientId: currentUser.id)
    ///      return userToken
    ///  })
    ///  ```
    public func connectUser(
        _ user: ClientUser,
        tokenProvider: @Sendable @escaping () async throws -> String
    ) async throws(OctopusConnectUserError) {
        do {
            try await core.connectionRepository.connectUser(user.coreValue, tokenProvider: tokenProvider)
        } catch {
            throw OctopusConnectUserError(from: error)
        }
    }

    /// Connect a user to the Octopus SDK.
    ///
    /// This is the fire-and-forget version of ``connectUser(_:tokenProvider:)``. Errors are logged but not
    /// propagated to the caller.
    ///
    /// - Note: This function should only be called when connectionMode is `.sso`.
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
    /// - Throws: An error if the disconnection fails.
    public func disconnectUser() async throws {
        try await core.connectionRepository.disconnectUser()
    }

    /// Disconnect the current user.
    ///
    /// This is the fire-and-forget version of ``disconnectUser()``. Errors are logged but not
    /// propagated to the caller.
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
    ///
    /// Pass the `userInfo` dictionary of the push notification (i.e. the
    /// `request.content.userInfo` of a `UNNotification`, or the raw payload map received
    /// from cross-platform push plugins like Firebase Messaging).
    /// If this function returns `true`, you should display the Octopus UI and forward the
    /// same `userInfo` to `OctopusHomeScreen`'s `notificationUserInfo:` binding.
    ///
    /// - Parameter userInfo: the push notification's `userInfo` dictionary
    /// - Returns: `true` if the notification is an Octopus Community one
    public static func isAnOctopusNotification(userInfo: [AnyHashable: Any]) -> Bool {
        NotificationsRepository.isAnOctopusNotification(userInfo: userInfo)
    }

    /// Gets whether this notification has been triggered by an Octopus Community content.
    /// - Parameter notification: the notification to test
    /// - Returns: true if the notification is an Octopus Community one
    @available(*, deprecated, renamed: "isAnOctopusNotification(userInfo:)",
               message: "Use isAnOctopusNotification(userInfo:) so the same API works for non-native wrappers (Flutter, React Native, Unity).")
    public static func isAnOctopusNotification(notification: UNNotification) -> Bool {
        isAnOctopusNotification(userInfo: notification.request.content.userInfo)
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
    /// Gets the Octopus post related to the given object id.
    /// 
    /// If the Octopus post does not exist yet, it will be created. The content will only be used if the post does not
    /// exist yet.
    /// 
    /// This function is asynchrounous and may take some time, if it is called after a user interaction, you should
    /// display a loader.
    /// - Parameters:
    ///   - content: the content of the post
    ///   - tokenProvider: a block called only if the post needs to be created. In that case, a signature will be
    ///                    required. This block gives you the bridge fingerprint that you should include in the jwt
    ///                    token that you return in this block. It will be used to ensure that the post content has been
    ///                    generated by you only. If you configured your community to have no signature on bridge posts
    ///                    you can return nil.
    ///                    If you want to compute the bridge fingerprint yourself to spare a network call, please read
    ///                    the Octopus documentation about how to create the jwt for bridge posts.
    /// - Returns: the Octopus post
    /// - Note: You can use the returned post id to display the post using `OctopusHomeScreen(octopus:postId:)`
    public func fetchOrCreateClientObjectRelatedPost(
        content: ClientPost,
        tokenProvider: @Sendable @escaping (_ bridgeFingerprint: String) async throws -> String?)
    async throws(ClientPostError) -> any OctopusPost {
        do {
            return try await core.postsRepository.getOrCreateClientObjectRelatedPost(
                content: content.coreValue, tokenProvider: tokenProvider)
        } catch {
            throw ClientPostError(from: error)
        }
    }

    /// Gets a publisher on a post given a client object id.
    /// The publisher will be updated when you call the `fetchOrCreateClientObjectRelatedPost` function and also
    /// sometimes due to internal updates of the post.
    /// - Parameter clientObjectId: the client object id
    /// - Returns: a publishers of an optional OctopusPost.
    public func getClientObjectRelatedPostPublisher(clientObjectId: String) -> AnyPublisher<(any OctopusPost)?, Never> {
        core.postsRepository.getClientObjectRelatedPost(clientObjectId: clientObjectId)
            .replaceError(with: nil)
            .map { $0 as (any OctopusPost)? }
            .eraseToAnyPublisher()
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

    /// Sets a reaction on the user's behalf on a given client object related post (i.e. bridge post)
    /// - Parameters:
    ///   - reaction: the reaction to set.
    ///               Nil if the reaction should be removed.
    ///               `.unknown` reactions are not supported.
    ///   - clientObjectRelatedPostId: the post id
    ///
    /// - Throws: an error if:
    ///   - no network
    ///   - you pass an `unknown` reaction
    ///   - the post id does not match with an existing post
    ///   - the post is not a client object related post (i.e. a bridge post)
    ///   - other internal errors
    public func set(reaction: OctopusReactionKind?, clientObjectRelatedPostId: String) async throws {
        try await core.postsRepository.set(reaction: reaction?.coreValue,
                                           clientObjectRelatedPostId: clientObjectRelatedPostId)
    }

    /// Fetches the groups from the backend values
    /// - Note: Even if you do not call `fetchGroups()`, the update might be done internally by the SDK at any time.
    public func fetchGroups() async throws {
        try await core.topicsRepository.fetchTopics()
    }

    /// Fetches the topics from the backend values
    @available(*, deprecated, renamed: "fetchGroups()")
    public func fetchTopics() async throws {
        try await fetchGroups()
    }

    /// Syncs a batch of follow/unfollow actions for the connected user, with per-action timestamps.
    ///
    /// The backend applies each action only if its ``OctopusSyncFollowGroup/Action/actionDate`` is
    /// more recent than the stored state for that (user, group) pair. Stale actions are silently
    /// returned as ``OctopusSyncFollowGroup/Status/skipped``.
    ///
    /// Passing an empty `actions` list is a no-op: returns an empty array without making a
    /// network call.
    ///
    /// On success, the SDK refreshes its local groups cache before returning, so the published
    /// ``groups`` array reflects the new state when the call returns.
    ///
    /// - Parameter actions: the actions to sync.
    /// - Returns: one ``OctopusSyncFollowGroup/Result`` per action in the batch. Each result
    ///   carries its own `groupId` — callers should match results to inputs by `groupId`
    ///   rather than relying on order.
    /// - Throws: ``OctopusSyncFollowGroup/Error`` for RPC-level failures (not per-action).
    public func syncFollowGroups(
        actions: [OctopusSyncFollowGroup.Action]
    ) async throws(OctopusSyncFollowGroup.Error) -> [OctopusSyncFollowGroup.Result] {
        do {
            let coreResults = try await core.topicsRepository.syncFollowTopics(
                actions: actions.map { $0.coreValue })
            return coreResults.map { OctopusSyncFollowGroup.Result(from: $0) }
        } catch {
            throw OctopusSyncFollowGroup.Error(from: error)
        }
    }

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
    @available(*, deprecated, message: "Use instead fetchOrCreateClientObjectRelatedPost(content: ClientPost). The new function returns more than just an id.")
    public func getOrCreateClientObjectRelatedPostId(content: ClientPost) async throws(ClientPostError) -> String {
        do {
            return try await core.postsRepository.getOrCreateClientObjectRelatedPostId(content: content.coreValue)
        } catch {
            throw ClientPostError(from: error)
        }
    }

    /// Gets the Octopus post related to the given object id.
    ///
    /// If the Octopus post does not exist yet, it will be created. The content will only be used if the post does not
    /// exist yet.
    ///
    /// This function is asynchrounous and may take some time, if it is called after a user interaction, you should
    /// display a loader.
    /// - Parameter content: the content of the post
    /// - Returns: the Octopus post
    /// - Note: You can use the returned post id to display the post using `OctopusHomeScreen(octopus:postId:)`
    @available(*, deprecated, message: "Use instead fetchOrCreateClientObjectRelatedPost(content: ClientPost, tokenProvider: (String) async -> String?). The new function has en enhanced security.")
    public func fetchOrCreateClientObjectRelatedPost(content: ClientPost) async throws(ClientPostError)
    -> any OctopusPost {
        do {
            return try await core.postsRepository.getOrCreateClientObjectRelatedPost(content: content.coreValue)
        } catch {
            throw ClientPostError(from: error)
        }
    }
}

// MARK: - URL catch
extension OctopusSDK {
    /// Set the callback that will be called when a user tries to open a link inside the community.
    /// This link can come from a Post/Comment/Reply or when tapping on a Post with CTA button.
    ///
    /// If this function is never called, or called with nil, it will behave as if the result is `handledByOctopus`,
    /// meaning that all links will be opened by Octopus using `UIApplication.shared.open(URL)`.
    ///
    /// - Parameters:
    ///   - onNavigateToURLCallback: the callback that will be called when a user tries to open a link inside
    ///                              the community.
    ///                              The parameter of the callback is the URL to open.
    ///                              If this callback returns `.handledByApp`, it means that the app has handled the
    ///                              URL itself, hence the Octopus SDK won't do anything more.
    ///                              If it is `handledByOctopus`, the URL will be opened by the Octopus SDK using
    ///                              `UIApplication.shared.open(URL)`.
    public func set(onNavigateToURLCallback: ((URL) -> URLOpeningStrategy)?) {
        self.onNavigateToURLCallback = onNavigateToURLCallback
    }
}

// MARK: - Language
extension OctopusSDK {
    /// Override the default (i.e. system or app based) locale.
    /// 
    /// Some apps do not use the default way of handling the language which provide the system/app defined language by
    /// the user. If you have a custom setting inside your app that does not set the system AppLanguage, you can call
    /// this function in order to customize the language used (so Octopus does not use the system language but yours
    /// instead).
    /// That being said, we recommend using the default system way of handling the locale, so system alerts are
    /// displayed in the desired language.
    ///
    /// The locale should respect the BCP-47 standard: it can have a language and an optional region.
    /// The language must be two letters [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes)
    /// and the region should be two letters [ISO 3166-1](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements).
    /// If the region is provided, it should be separated from the country by a `-`.
    /// For example: Locale(identifier: "fr") or Locale(identifier: "fr-BE")
    ///
    /// - Parameter locale: the locale that you want to set. Set nil if you want Octopus to use the system setting.
    public func overrideDefaultLocale(with locale: Locale?) {
        core.languageRepository.overrideDefaultLocale(with: locale)
    }
}

// MARK: - Switch Community
extension OctopusSDK {
    /// Change the API Key used in order to target a new community.
    ///
    /// Use this function when you need to change of community.
    ///
    /// - Note:
    ///   - During the call of this function, you must not call any other Octopus function until this function finishes.
    ///   - After this function finishes:
    ///     - you should call `connectUser` if you are in SSO and have a user, in order to
    ///       connect this user to the new community.
    ///     - you should reconstruct any OctopusHomeScreen that you have (you can use an `.id` in order to force re-init
    ///       of the view).
    ///
    /// - Parameters:
    ///   - apiKey: the API key that identifies the new community
    ///   - connectionMode: the kind of connection to handle the user. Default is Octopus connection mode.
    ///   - configuration: the sdk configuration. Default is default configuration.
    public func switchCommunity(
        apiKey: String,
        connectionMode: ConnectionMode = .octopus(deepLink: nil),
        configuration: Configuration = .init()
    ) async throws {
        storage.removeAll()

        if #available(iOS 14, *) { Logger.config.trace("Switching community") }
        let notificationDeviceToken = core.notificationsRepository.latestNotificationDeviceToken
        if #available(iOS 14, *) { Logger.config.trace("Cleaning up before switch") }
        try await core.cleanupBeforeCommunitySwitch()

        if #available(iOS 14, *) { Logger.config.trace("Recreating internal objects with new apiKey") }
        injector = Injector()
        core = try OctopusSDKCore(apiKey: apiKey,
                                  connectionMode: connectionMode.coreValue,
                                  sdkConfig: configuration.coreValue,
                                  cleanAfterCommunitySwitch: true,
                                  injector: injector)

        registerPublishers()

        if let notificationDeviceToken {
            core.notificationsRepository.set(notificationDeviceToken: notificationDeviceToken)
        }
    }
}
