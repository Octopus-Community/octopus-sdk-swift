//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public enum PollVote {
    public enum Field: Sendable, Hashable {
    }

    public enum ErrorDetail: Sendable {
        case unknown
        case missingParent
        case missingPollAnswer
    }

    public typealias Error = AuthenticatedInputActionError<ValidationErrors<Field, ErrorDetail>>
}

extension ValidationErrors where Field == PollVote.Field, ErrorDetail == PollVote.ErrorDetail {
    init(from failure: Com_Octopuscommunity_PutPollVoteResponse.Fail) {
         var dictionary = [DisplayKind: [ValidationErrors.Error]]()
         for error in failure.errors {
             let display: ValidationErrors.DisplayKind = switch error.field {
             case .contentParent:            .alert // not used for the moment
             case .contentTarget:            .alert
             case .unknown, .UNRECOGNIZED:   .alert
             }
             let detail: ErrorDetail = switch error.details {
             case .missingParent:                   .missingParent
             case .missingPollAnswer:               .missingPollAnswer
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

