//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels

public struct User: Sendable {
    public let profile: CurrentUserProfile
    let jwtToken: String
}

public struct MagicLinkRequest {
    public let email: String
    public let error: MagicLinkConfirmationError?
}

public enum ConnectionState {
    case notConnected
    case magicLinkSent(MagicLinkRequest)
    case clientConnected(ClientUser, ExchangeTokenError?)
    case profileCreationRequired(clientProfile: ClientUserProfile, lockedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>?)
    case connected(User)

    public var user: User? {
        switch self {
        case .connected(let user):
            return user
        default: return nil
        }
    }
}

extension Injected {
    static let connectionRepository = Injector.InjectedIdentifier<ConnectionRepository>()
}

public protocol ConnectionRepository: Sendable {
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }
    var connectionState: ConnectionState { get }
    var connectionMode: ConnectionMode { get }
    func sendMagicLink(to email: String) async throws(MagicLinkEmailEntryError)
    func cancelMagicLink()
    func checkMagicLinkConfirmed() async throws(MagicLinkConfirmationError) -> Bool
    func logout() async throws
    func deleteAccount(reason: DeleteAccountReason) async throws(AuthenticatedActionError)

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws
    func disconnectUser() async throws
    /// Link a client user to an Octopus one.
    /// This function does not normally have to be called since it is automatically called. However, if an error
    /// occured, during the automatic call, you might have to call it again when a user needs to be authenticated.
    func linkClientUserToOctopusUser() async throws(ExchangeTokenError)
}

/// All errors that can be thrown during authentication with magic link
public enum MagicLinkEmailEntryError: Error {
    public struct DetailedError: Sendable {
        public enum Reason: Sendable {
            case userBanned
            case unknown
        }
        public let reason: Reason
        public let message: String

        init(from error: Com_Octopuscommunity_GenerateLinkResponse.GenerateLinkErrorDetail) {
            message = error.message
            reason = switch error.errorCode {
            case .userBanned:
                .userBanned
            case .unknownError, .UNRECOGNIZED:
                .unknown
            }
        }
    }
    case noNetwork
    case detailedError(DetailedError)
    case server(ServerError)
    case unknown(Error?)
}

/// All errors that can be thrown during authentication with magic link
public enum MagicLinkConfirmationError: Error {
    case noNetwork
    case noMagicLink
    case magicLinkExpired
    case needNewMagicLink
    case userBanned(String)
    case unknown(Error?)
}

public enum ExchangeTokenError: Error {
    public struct DetailedError: Sendable {
        public enum Reason: Sendable {
            case userBanned
            case unknown
        }
        public let reason: Reason
        public let message: String

        init(from error: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse.Error) {
            message = error.message
            reason = switch error.errorCode {
            case .userBanned:
                .userBanned
            case .unknownError, .UNRECOGNIZED:
                .unknown
            }
        }
    }
    case noNetwork
    case detailedErrors([DetailedError])
    case server(ServerError)
    case unknown(Error?)
}
