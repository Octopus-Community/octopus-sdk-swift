//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public enum GetOrCreateClientPost {
    public enum Field: Sendable {
        case text
        case file
        case clientObject
    }

    public enum ErrorDetail: Sendable {
        case unknown
        case missingText
        case maxCharLimitReached
        case emptyFile
        case fileSizeTooBig
        case badFileFormat
        case uploadIssue
        case downloadIssue
        case missingCtaText
        case missingClientObjectId
        case invalidClientToken
        case bridgePostUnavailable
        case expiredClientToken
        case invalidTopicId
        case invalidAuthor
    }

    public typealias Error = AuthenticatedInputActionError<ValidationErrors<Field, ErrorDetail>>
}

extension ValidationErrors where Field == GetOrCreateClientPost.Field, ErrorDetail == GetOrCreateClientPost.ErrorDetail {
     init(from failure: Com_Octopuscommunity_GetOrCreateBridgePostResponse.Fail) {
         var dictionary = [DisplayKind: [ValidationErrors.Error]]()
         for error in failure.errors {
             let display: ValidationErrors.DisplayKind = switch error.field {
             case .contentText:              .linkedToField(.text)
             case .contentFile:              .linkedToField(.file)
             case .contentClientObject:      .linkedToField(.clientObject)
             case .unknown, .UNRECOGNIZED:   .alert
             }
             let detail: ErrorDetail = switch error.details {
             case .missingText:              .missingText
             case .maxCharLimitReached:      .maxCharLimitReached
             case .emptyFile:                .emptyFile
             case .fileSizeTooBig:           .fileSizeTooBig
             case .badFileFormat:            .badFileFormat
             case .uploadIssue:              .uploadIssue
             case .downloadIssue:            .downloadIssue
             case .missingCtaText:           .missingCtaText
             case .missingClientObjectID:    .missingClientObjectId
             case .invalidClientToken:       .invalidClientToken
             case .bridgePostUnavailable:    .bridgePostUnavailable
             case .expiredClientToken:       .expiredClientToken
             case .invalidTopicID:           .invalidTopicId
             case .invalidAuthor:            .invalidAuthor
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

