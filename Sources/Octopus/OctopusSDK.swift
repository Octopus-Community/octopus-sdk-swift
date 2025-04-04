import Foundation
import OctopusCore
import OctopusDependencyInjection
import os

/// Octopus Community main model object.
/// This object holds a reference on all the repositories.
public class OctopusSDK: ObservableObject {
    /// Core interface. This object should not be used by external devs, it is only used by the UI lib
    public let core: OctopusSDKCore
    private let injector: Injector
    
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
