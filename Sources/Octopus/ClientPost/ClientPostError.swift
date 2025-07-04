//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// Errors that can be returned by `getOrCreateClientObjectRelatedPostId(content:)`.
public enum ClientPostError: Error {
    /// Content error. Associated value is a list of the detailed errors present in the content
    case validation([ValidationError])
    /// User do not have any internet connection at the time of the call
    case noNetwork
    /// Server error
    case serverError
    /// Other error
    case other(Swift.Error?)
    
    /// An error linked to the provided content
    public struct ValidationError: Sendable {
        /// The kind of error
        let errorKind: ErrorKind
        /// The field that produced the error. Can be nil
        let field: Field?
        /// An explanation of the error
        let message: String

        /// Kind of error
        public enum ErrorKind: Sendable {
            case unknown
            /// The text of the post cannot be empty
            case missingText
            /// The fields linked to this error has reached its max length
            case maxCharLimitReached
            /// The file is empty
            case emptyFile
            /// The file is too big
            case fileSizeTooBig
            /// The file format is not supported
            case badFileFormat
            /// There was an error when storing the file
            case uploadIssue
            /// There was an error when getting the remote file
            case downloadIssue
            /// The CTA text is empty
            case missingCtaText
            /// The client object id is missing
            case missingClientObjectId
            /// The signature is invalid
            case invalidClientToken
            case bridgePostUnavailable
            /// The signature is expired
            case expiredClientToken
            /// The topic id is invalid
            case invalidTopicId
            /// The author (the account designed to post the bridges) is invalid.
            case invalidAuthor
        }

        /// The field that produced the error
        public enum Field: Sendable {
            case text
            case file
            case clientObject
        }
    }
}

extension ClientPostError {
    init(from error: GetOrCreateClientPost.Error) {
        self = switch error {
        case let .validation(validation):
                .validation(
                    validation.errors.flatMap { field, errors in
                        errors.map {
                            ValidationError(errorKind: .init(from: $0.detail),
                                            field: .init(from: field),
                                            message: $0.localizedMessage)
                        }
                    }
                )
        case let .serverCall(serverError):
            switch serverError {
            case .userNotAuthenticated: .other(nil) // should not happen as the call is not an authenticated one
            case .noNetwork: .noNetwork
            case .serverError: .serverError
            case let .other(error): .other(error)
            }
        }
    }
}

private extension ClientPostError.ValidationError.Field {
    init?(from displayKind: ValidationErrors<GetOrCreateClientPost.Field, GetOrCreateClientPost.ErrorDetail>.DisplayKind) {
        switch displayKind {
        case let .linkedToField(field):
            switch field {
            case .text: self = .text
            case .file: self = .file
            case .clientObject: self = .clientObject
            }
        case .alert: return nil
        }

    }
}

private extension ClientPostError.ValidationError.ErrorKind {
    init(from detail: GetOrCreateClientPost.ErrorDetail) {
        self = switch detail {
        case .unknown: .unknown
        case .missingText: .missingText
        case .maxCharLimitReached: .maxCharLimitReached
        case .emptyFile: .emptyFile
        case .fileSizeTooBig: .fileSizeTooBig
        case .badFileFormat: .badFileFormat
        case .uploadIssue: .uploadIssue
        case .downloadIssue: .downloadIssue
        case .missingCtaText: .missingCtaText
        case .missingClientObjectId: .missingClientObjectId
        case .invalidClientToken: .invalidClientToken
        case .bridgePostUnavailable: .bridgePostUnavailable
        case .expiredClientToken: .expiredClientToken
        case .invalidTopicId: .invalidTopicId
        case .invalidAuthor: .invalidAuthor
        }
    }
}
