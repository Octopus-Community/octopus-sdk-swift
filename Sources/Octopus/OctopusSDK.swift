import Foundation
import Combine
import OctopusCore
import OctopusDependencyInjection
import os

/// Octopus Community main model object.
/// This object holds a reference on all the repositories.
public class OctopusSDK: ObservableObject {
    
    /// Number of notifications from the notification center (i.e. internal notifications) that have not been seen yet.
    /// Always 0 if the user is not connected to Octopus Community.
    @Published public private(set) var notSeenNotificationsCount: Int = 0

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

        core.profileRepository.$profile
            .sink { [unowned self] in
                let newNotSeenNotificationsCount = $0?.notificationBadgeCount ?? 0
                guard notSeenNotificationsCount != newNotSeenNotificationsCount else { return }
                notSeenNotificationsCount = newNotSeenNotificationsCount
            }.store(in: &storage)
    }

    /// Sets whether the access to the Octopus community is enabled or not.
    /// 
    /// This method indicates whether the app should have access to community features,
    /// typically used in A/B testing scenarios where some users may be excluded from the community
    /// experience. This information is used internally for analytics and tracking purposes to
    /// understand user engagement patterns.
    ///
    /// - Parameter hasAccessToCommunity: True if the app has access to the community features, false if it
    ///                                   should be excluded (e.g., in A/B testing control groups)
    public func set(hasAccessToCommunity: Bool) {
        core.trackingRepository.set(hasAccessToCommunity: hasAccessToCommunity)
    }

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
