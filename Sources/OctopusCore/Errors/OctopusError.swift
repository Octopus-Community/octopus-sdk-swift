//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient

public enum AuthenticatedInputActionError<ValidationError: Sendable>: Error, CustomDebugStringConvertible {
    case validation(ValidationError)
    case serverCall(AuthenticatedActionError)
    case other(Error?)

    public var debugDescription: String {
        switch self {
        case let .validation(error): "Validation error: \(error) (AuthenticatedInputActionError.validation)"
        case let .serverCall(error): "Server error: \(error) (AuthenticatedInputActionError.serverCall)"
        case let .other(error): "Other error: \(String(describing: error)) (AuthenticatedInputActionError.other)"
        }
    }
}

public enum AuthenticatedActionError: Error {
    case userNotAuthenticated
    case noNetwork
    case serverError(ServerError)
    case other(Error?)
}

public enum ServerCallError: Error {
    case noNetwork
    case serverError(ServerError)
    case other(Error?)
}

enum InternalError: Error {
    case objectMalformed
    case invalidArgument
    case wrongConnectionMode
    case incorrectState
    case timeout
    case explainedError(String)
    case userIdNotMatching
    case objectNotFound
}

/// Errors that can be returned by the server. Most of the time, they are technicall errors, either developer based
/// (like .notAuthenticated if you're calling this API without having an authenticated user) or backend based.
public enum ServerError: Error {
    case cancelled
    case timeout
    case notAuthenticated(reason: String?)
    case notFound
    case unknown(Error)

    init(remoteClientError: RemoteClientError) {
        switch remoteClientError {

        case .cancelled:                    self = .cancelled
        case .timeout:                      self = .timeout
        case let .notAuthenticated(reason): self = .notAuthenticated(reason: reason)
        case .notFound:                     self = .notFound
        case let .unknown(error):           self = .unknown(error)
        }
    }
}
