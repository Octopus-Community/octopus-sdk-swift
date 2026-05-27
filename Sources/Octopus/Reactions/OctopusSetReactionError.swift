//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// Errors that can be thrown by ``OctopusSDK/set(reaction:postId:)``.
public enum OctopusSetReactionError: Error, CustomDebugStringConvertible {
    /// Caller passed an `OctopusReactionKind.unknown(...)` raw case.
    case unknownReaction
    /// The post id does not exist, or the current user has no read access to it.
    case postNotFound
    /// No user is connected.
    case notConnected
    /// No network connection is available.
    case noNetwork
    /// The backend returned an error.
    case serverError(Error)
    /// An unclassified failure.
    case other(Error?)

    public var debugDescription: String {
        switch self {
        case .unknownReaction:
            return "Unknown reaction not permitted (OctopusSetReactionError.unknownReaction)"
        case .postNotFound:
            return "Post not found (OctopusSetReactionError.postNotFound)"
        case .notConnected:
            return "No user is connected (OctopusSetReactionError.notConnected)"
        case .noNetwork:
            return "No network (OctopusSetReactionError.noNetwork)"
        case let .serverError(error):
            return "Server error: \(error) (OctopusSetReactionError.serverError)"
        case let .other(error):
            return "Other error: \(String(describing: error)) (OctopusSetReactionError.other)"
        }
    }
}

extension OctopusSetReactionError {
    init(from coreError: SetReactionOnPostError) {
        switch coreError {
        case .unknownReaction:
            self = .unknownReaction
        case .postNotFound:
            self = .postNotFound
        case let .reactionError(reactionError):
            self = OctopusSetReactionError(from: reactionError)
        }
    }

    private init(from reactionError: Reaction.Error) {
        switch reactionError {
        case let .serverCall(serverError):
            switch serverError {
            case .userNotAuthenticated:
                self = .notConnected
            case .noNetwork:
                self = .noNetwork
            case let .serverError(error):
                self = .serverError(error)
            case let .other(error):
                self = .other(error)
            }
        case .validation:
            self = .other(reactionError)
        case let .other(error):
            self = .other(error)
        }
    }
}
