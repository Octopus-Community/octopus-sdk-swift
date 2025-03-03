//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

public enum SendComment {
    public enum Field: Sendable {
        case text
        case picture
    }

    public enum ErrorDetail: Sendable {
        case unknown
        case missingParent
        case bannedWordUsed([String])
        case maxCharLimitReached
        case emptyFile
        case fileSizeTooBig
        case badFileFormat
        case uploadIssue
        case emptyPublication
    }

    public typealias Error = AuthenticatedInputActionError<ValidationErrors<Field, ErrorDetail>>
}

extension ValidationErrors where Field == SendComment.Field, ErrorDetail == SendComment.ErrorDetail {
    init(from failure: Com_Octopuscommunity_PutCommentResponse.Fail) {
        var dictionary = [DisplayKind: [ValidationErrors.Error]]()
        for error in failure.errors {
            let display: ValidationErrors.DisplayKind = switch error.field {
            case .contentText:              .linkedToField(.text)
            case .contentFile:              .linkedToField(.picture)
            case .contentParent:            .alert // not used for the moment
            case .unknown, .UNRECOGNIZED:   .alert
            }
            let detail: ErrorDetail = switch error.details {
            case .missingParent:                   .missingParent
            case let .bannedWordUsed(bannedWords): .bannedWordUsed(bannedWords.words)
            case .maxCharLimitReached:             .maxCharLimitReached
            case .emptyFile:                       .emptyFile
            case .fileSizeTooBig:                  .fileSizeTooBig
            case .badFileFormat:                   .badFileFormat
            case .uploadIssue:                     .uploadIssue
            case .emptyPublication:                .emptyPublication
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
