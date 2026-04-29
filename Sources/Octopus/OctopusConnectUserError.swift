//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// Errors that can be thrown by ``OctopusSDK/connectUser(_:tokenProvider:)``.
public enum OctopusConnectUserError: Error, CustomDebugStringConvertible {
    /// The user has been banned from the community.
    case userBanned(String)
    /// An error occurred while updating the user profile during connection.
    case profileError([ProfileValidationError])
    /// The JWT token provided by the token provider is invalid (bad signature or algorithm).
    case jwtError
    /// The user does not have access to the community (e.g. due to A/B testing restrictions).
    case communityAccessDenied
    /// No network connection is available.
    case noNetwork
    /// A server error occurred.
    case server(Error)
    /// An unknown error occurred.
    case other(Error?)

    /// An error linked to the user profile during connection.
    public struct ProfileValidationError: Sendable, CustomDebugStringConvertible {
        /// The kind of error.
        public let errorKind: ErrorKind
        /// The field that produced the error. Can be nil for alert-level errors.
        public let field: Field?
        /// An explanation of the error. This message is already localized.
        public let message: String

        /// Kind of profile validation error.
        public enum ErrorKind: Sendable {
            case unknown
            /// A banned word was used in the field.
            case bannedWordUsed([String])
            /// The field has reached its max character limit.
            case maxCharLimitReached
            /// The nickname is already taken by another user.
            case alreadyTaken
            /// The field value has a bad format.
            case badFormat
            /// The file is empty.
            case emptyFile
            /// The file is too big.
            case fileSizeTooBig
            /// The file format is not supported.
            case badFileFormat
            /// There was an error when storing the file.
            case uploadIssue
            /// The content was rejected by moderation.
            case moderatedContent
            /// An avatar update is already in process.
            case avatarInProcess
        }

        /// The profile field that produced the error.
        public enum Field: Sendable {
            case nickname
            case bio
            case picture
        }

        public var debugDescription: String {
            "\"\(errorKind)\": \(message) \(field.map { "(on field \"\($0)\")" } ?? "")"
        }
    }

    public var debugDescription: String {
        switch self {
        case let .userBanned(message):
            "User banned: \(message) (OctopusConnectUserError.userBanned)"
        case let .profileError(errors):
            "Profile error: \(errors.map { "\($0)" }.joined(separator: ", ")) (OctopusConnectUserError.profileError)"
        case .jwtError:
            "Invalid JWT token (OctopusConnectUserError.jwtError)"
        case .communityAccessDenied:
            "Community access denied (OctopusConnectUserError.communityAccessDenied)"
        case .noNetwork:
            "No network (OctopusConnectUserError.noNetwork)"
        case let .server(serverError):
            "Server error \(String(describing: serverError)) (OctopusConnectUserError.serverError)"
        case let .other(error):
            "\(String(describing: error)) (OctopusConnectUserError.other)"
        }
    }
}

extension OctopusConnectUserError {
    init(from error: Error) {
        if let connectionError = error as? ConnectionError {
            self = Self.from(connectionError: connectionError)
        } else if let exchangeTokenError = error as? ExchangeTokenError {
            self = Self.from(exchangeTokenError: exchangeTokenError)
        } else {
            self = .other(error)
        }
    }

    private static func from(connectionError: ConnectionError) -> OctopusConnectUserError {
        switch connectionError {
        case .noNetwork:
            return .noNetwork
        case let .detailedErrors(errors):
            if let bannedError = errors.first(where: { $0.reason == .userBanned }) {
                return .userBanned(bannedError.message)
            }
            return .other(connectionError)
        case let .server(serverError):
            return .server(serverError)
        case .jwtError:
            return .jwtError
        case .communityAccessDenied:
            return .communityAccessDenied
        case let .profileUpdateError(updateError):
            return .from(profileUpdateError: updateError)
        case let .unknown(underlyingError):
            return .other(underlyingError)
        }
    }

    private static func from(exchangeTokenError: ExchangeTokenError) -> OctopusConnectUserError {
        switch exchangeTokenError {
        case .noNetwork:
            return .noNetwork
        case let .detailedErrors(errors):
            if let bannedError = errors.first(where: { $0.reason == .userBanned }) {
                return .userBanned(bannedError.message)
            }
            return .other(exchangeTokenError)
        case let .server(serverError):
            return .server(serverError)
        case .jwtError:
            return .jwtError
        case .communityAccessDenied:
            return .communityAccessDenied
        case let .profileUpdateError(updateError):
            return .from(profileUpdateError: updateError)
        case let .unknown(underlyingError):
            return .other(underlyingError)
        }
    }

    private static func from(profileUpdateError: UpdateProfile.Error) -> OctopusConnectUserError {
        switch profileUpdateError {
        case let .validation(validationErrors):
            return .profileError(
                validationErrors.errors.flatMap { displayKind, errors in
                    errors.map {
                        ProfileValidationError(
                            errorKind: .init(from: $0.detail),
                            field: .init(from: displayKind),
                            message: $0.localizedMessage)
                    }
                }
            )
        case let .serverCall(serverError):
            switch serverError {
            case .userNotAuthenticated: return .other(nil)
            case .noNetwork: return .noNetwork
            case let .serverError(serverError):
                return .server(serverError)
            case let .other(error): return .other(error)
            }
        case let .other(error):
            return .other(error)
        }
    }
}

private extension OctopusConnectUserError.ProfileValidationError.Field {
    init?(from displayKind: ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>.DisplayKind) {
        switch displayKind {
        case let .linkedToField(field):
            switch field {
            case .nickname: self = .nickname
            case .bio: self = .bio
            case .picture: self = .picture
            }
        case .alert: return nil
        }
    }
}

private extension OctopusConnectUserError.ProfileValidationError.ErrorKind {
    init(from detail: UpdateProfile.ErrorDetail) {
        self = switch detail {
        case .unknown: .unknown
        case let .bannedWordUsed(words): .bannedWordUsed(words)
        case .maxCharLimitReached: .maxCharLimitReached
        case .alreadyTaken: .alreadyTaken
        case .badFormat: .badFormat
        case .emptyFile: .emptyFile
        case .fileSizeTooBig: .fileSizeTooBig
        case .badFileFormat: .badFileFormat
        case .uploadIssue: .uploadIssue
        case .moderatedContent: .moderatedContent
        case .avatarInProcess: .avatarInProcess
        }
    }
}
