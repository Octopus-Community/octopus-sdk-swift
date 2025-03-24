//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public enum UpdateProfile {
    public enum Field: Sendable {
        case nickname
        case bio
        case picture
    }

    public enum ErrorDetail: Sendable {
        case unknown
        case bannedWordUsed([String])
        case maxCharLimitReached
        case alreadyTaken
        case badFormat
        case emptyFile
        case fileSizeTooBig
        case badFileFormat
        case uploadIssue
        case moderatedContent
        case avatarInProcess
    }
    /// All errors that can be thrown during profile update
    public typealias Error = AuthenticatedInputActionError<ValidationErrors<Field, ErrorDetail>>
}

extension ValidationErrors where Field == UpdateProfile.Field, ErrorDetail == UpdateProfile.ErrorDetail {
    init(from failure: Com_Octopuscommunity_UpdateProfileResponse.Fail) {
        var dictionary = [DisplayKind: [ValidationErrors.Error]]()
        for error in failure.errors {
            let display: ValidationErrors.DisplayKind = switch error.field {
            case .nickname:                 .linkedToField(.nickname)
            case .profilePicture:           .linkedToField(.picture)
            case .bio:                      .linkedToField(.bio)
            case .email:                    .alert // not used for the moment
            case .unknown, .UNRECOGNIZED:   .alert
            }
            let detail: ErrorDetail = switch error.details {
            case let .bannedWordUsed(bannedWords):  .bannedWordUsed(bannedWords.words)
            case .alreadyTaken:                     .alreadyTaken
            case .badFormat:                        .badFormat
            case .emptyFile:                        .emptyFile
            case .fileSizeTooBig:                   .fileSizeTooBig
            case .badFileFormat:                    .badFileFormat
            case .uploadIssue:                      .uploadIssue
            case .charLimitReached:                 .maxCharLimitReached
            case .moderatedContent:                 .moderatedContent
            case .avatarInProcess:                  .avatarInProcess
            case .none:                             .unknown
            }
            let formError = ValidationErrors.Error(localizedMessage: error.message, detail: detail)

            var errors = dictionary[display] ?? []
            errors.append(formError)
            dictionary[display] = errors
        }

        errors = dictionary
    }
}
