//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public enum Reaction {
    public enum Field: Sendable, Hashable {
    }

    public enum ErrorDetail: Sendable {
        case unknown
        case missingParent
    }

    public typealias Error = AuthenticatedInputActionError<ValidationErrors<Field, ErrorDetail>>
}

public enum SetReactionOnBridgePostError: Error, CustomDebugStringConvertible {
    case unknownReaction
    case postNotFound
    case postIsNotABridge
    case reactionError(Reaction.Error)

    public var debugDescription: String {
        switch self {
        case .unknownReaction: "Unknown reaction not permitted (SetReactionOnBridgePostError.unknownReaction)"
        case .postNotFound: "Post not found (SetReactionOnBridgePostError.postNotFound)"
        case .postIsNotABridge: "Post is not a bridge (SetReactionOnBridgePostError.postIsNotABridge)"
        case let .reactionError(error): "Set reaction failed: \(error) (SetReactionOnBridgePostError.reactionError)"
        }
    }
}

extension ValidationErrors where Field == Reaction.Field, ErrorDetail == Reaction.ErrorDetail {
    init(from failure: Com_Octopuscommunity_PutReactionResponse.Fail) {
        var dictionary = [DisplayKind: [ValidationErrors.Error]]()
        for error in failure.errors {
            let display: ValidationErrors.DisplayKind = switch error.field {
            case .contentParent:            .alert // not used for the moment
            case .unknown, .UNRECOGNIZED:   .alert
            }
            let detail: ErrorDetail = switch error.details {
            case .missingParent:                   .missingParent
            case .none:                            .unknown
            }
            let formError = ValidationErrors.Error(localizedMessage: error.message, detail: detail)

            var errors = dictionary[display] ?? []
            errors.append(formError)
            dictionary[display] = errors
        }

        errors = dictionary
    }
}
