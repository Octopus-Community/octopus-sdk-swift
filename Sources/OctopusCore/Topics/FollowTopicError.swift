//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public enum FollowTopic {
    public enum Field: Sendable, Hashable {
        // for the moment, there is no fields
    }

    public enum ErrorDetail: Sendable {
        case unknown
        case unfollowableTopic
        case topicNotFound
        case topicAlreadyFollowed
        case topicAlreadyUnfollowed
    }

    public typealias Error = AuthenticatedInputActionError<ValidationErrors<Field, ErrorDetail>>
}

extension ValidationErrors where Field == FollowTopic.Field, ErrorDetail == FollowTopic.ErrorDetail {
     init(from failure: Com_Octopuscommunity_FollowUnfollowTopicResponse.Fail) {
         var dictionary = [DisplayKind: [ValidationErrors.Error]]()
         for error in failure.errors {
             let display: ValidationErrors.DisplayKind = switch error.field {
             case .contentParent:            .alert // not used for the moment
             case .unknown, .UNRECOGNIZED:   .alert
             }
             let detail: ErrorDetail = switch error.details {
             case .missingParent:                   .topicNotFound
             case .unFollowableTopic:               .unfollowableTopic
             case .topicAlreadyFollowed:            .topicAlreadyFollowed
             case .topicAlreadyUnfollowed:          .topicAlreadyUnfollowed
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
