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

public enum ConnectionState {
    case notConnected(Error?)
    case connected(User, Error?)

    public var user: User? {
        switch self {
        case let .connected(user, _):
            return user
        default: return nil
        }
    }

    /// The server's explanation when the connection carries a ban, `nil` for every other state or error.
    ///
    /// The backend localizes that message from `Accept-Language`, so it is meant to be displayed as-is:
    /// it is the only connection failure that says something the SDK cannot say better itself.
    public var userBannedMessage: String? {
        switch self {
        case let .notConnected(error): Self.userBannedMessage(from: error)
        case let .connected(_, error): Self.userBannedMessage(from: error)
        }
    }

    private static func userBannedMessage(from error: Error?) -> String? {
        if let connectionError = error as? ConnectionError,
           case let .detailedErrors(errors) = connectionError {
            return errors.first { $0.reason == .userBanned }?.message
        }
        if let exchangeTokenError = error as? ExchangeTokenError,
           case let .detailedErrors(errors) = exchangeTokenError {
            return errors.first { $0.reason == .userBanned }?.message
        }
        return nil
    }
}

extension Injected {
    static let connectionRepository = Injector.InjectedIdentifier<ConnectionRepository>()
}

public protocol ConnectionRepository: Sendable {
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }
    var connectionState: ConnectionState { get }
    var clientUserConnected: Bool { get }
    var connectionMode: ConnectionMode { get }
    func onAuthenticatedCallFailed() async throws
    func logout() async throws
    /// Ends the session before the SDK is rebuilt on another community, a guest session included.
    ///
    /// The session is stored in a Keychain service shared by every community, and a guest JWT is only valid on the
    /// community that issued it. Kept, as `logout()` keeps it, the next community's core would read it and send it
    /// to a server that rejects it, failing the first calls until the SDK notices and forges a guest of its own.
    func logoutBeforeCommunitySwitch() async throws

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws
    func disconnectUser() async throws
    /// Link a client user to an Octopus one.
    /// This function does not normally have to be called since it is automatically called. However, if an error
    /// occured, during the automatic call, you might have to call it again when a user needs to be authenticated.
    func linkClientUserToOctopusUser() async throws(ExchangeTokenError)
    /// Refresh the connected user's entitlements via the backend.
    /// Throws `.noClientTokenProvider` while no `tokenProvider` has been registered through `connectUser`.
    func refreshEntitlements() async throws(RefreshEntitlementsCoreError)
}

/// Internal error type for `refreshEntitlements`. Translated to `OctopusRefreshEntitlementsError`
/// at the public SDK boundary.
public enum RefreshEntitlementsCoreError: Error {
    case noClientTokenProvider
    case notConnected
    case noNetwork
    /// The user has been banned from the community — message is BE-provided.
    case userBanned(String)
    case serverError(Error)
}

/// Backend-failure carrier used when the BE reports one or more non-banned errors during a
/// refreshEntitlements exchange. Wraps the joined messages so the public layer can surface
/// a meaningful description without resorting to `NSError`.
public struct RefreshEntitlementsServerError: Error, Sendable, CustomStringConvertible {
    public let messages: [String]

    public init(messages: [String]) {
        self.messages = messages
    }

    public var description: String { messages.joined(separator: ", ") }
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

        init(from error: ConnectionError.DetailedError) {
            message = error.message
            reason = switch error.reason {
            case .userBanned: .userBanned
            case .unknown: .unknown
            }
        }
    }
    case noNetwork
    case detailedErrors([DetailedError])
    case server(ServerError)
    case jwtError
    case communityAccessDenied
    case profileUpdateError(UpdateProfile.Error)
    case unknown(Error?)
}

extension ExchangeTokenError {
    init(from error: ConnectionError) {
        self = switch error {
        case .noNetwork: .noNetwork
        case let .detailedErrors(detailedErrors): .detailedErrors(detailedErrors.map { .init(from: $0) })
        case let .server(serverError): .server(serverError)
        case .jwtError: .jwtError
        case .communityAccessDenied: .communityAccessDenied
        case let .profileUpdateError(updateError): .profileUpdateError(updateError)
        case let .unknown(underlyingError): .unknown(underlyingError)
        }
    }
}

public enum ConnectionError: Error {
    public struct DetailedError: Sendable {
        public enum Reason: Sendable {
            case userBanned
            case unknown
        }
        public let reason: Reason
        public let message: String

        init(from error: Com_Octopuscommunity_GetGuestJwtResponse.Error) {
            message = error.message
            reason = switch error.errorCode {
            case .userBanned:
                .userBanned
            case .unknownError, .UNRECOGNIZED:
                .unknown
            }
        }

        init(from error: ExchangeTokenError.DetailedError) {
            message = error.message
            reason = switch error.reason {
            case .userBanned: .userBanned
            case .unknown: .unknown
            }
        }
    }
    case noNetwork
    case detailedErrors([DetailedError])
    case server(ServerError)
    case jwtError
    case communityAccessDenied
    case profileUpdateError(UpdateProfile.Error)
    case unknown(Error?)
}

extension ConnectionError {
    init(from error: ExchangeTokenError) {
        self = switch error {
        case .noNetwork: .noNetwork
        case let .detailedErrors(detailedErrors): .detailedErrors(detailedErrors.map { .init(from: $0) })
        case let .server(serverError): .server(serverError)
        case .jwtError: .jwtError
        case .communityAccessDenied: .communityAccessDenied
        case let .profileUpdateError(updateError): .profileUpdateError(updateError)
        case let .unknown(underlyingError): .unknown(underlyingError)
        }
    }
}
