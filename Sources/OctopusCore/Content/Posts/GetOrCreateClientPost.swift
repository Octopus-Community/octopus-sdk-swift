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
             case .postAlreadyExists:       .unknown // internal error that should be catched before
             case .postNotFound:            .unknown // internal error that should be catched before
             case .none:                    .unknown
             }
             let formError = ValidationErrors.Error(localizedMessage: error.message, detail: detail,
                                                    imageIndex: error.hasFileIndex ? Int(error.fileIndex) : nil)

             var errors = dictionary[display] ?? []
             errors.append(formError)
             dictionary[display] = errors
         }

         errors = dictionary
     }

     /// The server refused to create the upload URLs of the post's photos. A photo's error is about the file field,
     /// and carries the index of the photo at fault when the server gives one. The token and the bridge
     /// availability are checked by the upload too: their errors are displayed as the bridge post creation displays
     /// them, so that the caller gets the same error whether the post has local images or not.
     ///
     /// That index counts among the local images only (`ClientPost.localImages`, the ones uploaded), not among the
     /// post's medias, where distant images sit too. Nothing reads it today; convert it before exposing it.
     init(from failure: Com_Octopuscommunity_CreateImageUploadsResponse.Fail) {
         var dictionary = [DisplayKind: [ValidationErrors.Error]]()
         for error in failure.errors {
             let (display, detail): (DisplayKind, ErrorDetail) = switch error.details {
             case .emptyFile:             (.linkedToField(.file), .emptyFile)
             case .fileSizeTooBig:        (.linkedToField(.file), .fileSizeTooBig)
             case .invalidClientToken:    (.alert, .invalidClientToken)
             case .expiredClientToken:    (.alert, .expiredClientToken)
             case .bridgePostUnavailable: (.linkedToField(.clientObject), .bridgePostUnavailable)
             case .none:                  (.linkedToField(.file), .unknown)
             }
             dictionary[display, default: []].append(
                 ValidationErrors.Error(localizedMessage: error.message, detail: detail,
                                        imageIndex: error.hasFileIndex ? Int(error.fileIndex) : nil))
         }
         errors = dictionary
     }
 }

extension Com_Octopuscommunity_GetOrCreateBridgePostResponse.Fail {
    func hasError(_ searchedError: Com_Octopuscommunity_GetOrCreateBridgePostResponse.Error.OneOf_Details) -> Bool {
        for error in errors {
            if error.details == searchedError {
                return true
            }
        }
        return false
    }
}
