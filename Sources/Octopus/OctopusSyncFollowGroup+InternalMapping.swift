//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusSyncFollowGroup.Action {
    var coreValue: SyncFollowTopicAction {
        SyncFollowTopicAction(topicId: groupId, followed: followed, actionDate: actionDate)
    }
}

extension OctopusSyncFollowGroup.Result {
    init(from core: SyncFollowTopicResult) {
        self.groupId = core.topicId
        self.status = .init(from: core.status)
    }
}

extension OctopusSyncFollowGroup.Status {
    init(from core: SyncFollowTopicResult.Status) {
        self = switch core {
        case .applied:            .applied
        case .skipped:            .skipped
        case .topicNotFound:      .groupNotFound
        case .notFollowable:      .notFollowable
        case .notUnfollowable:    .notUnfollowable
        case .alreadyFollowed:    .alreadyFollowed
        case .alreadyUnfollowed:  .alreadyUnfollowed
        case .unknownError:       .unknownError
        }
    }
}

extension OctopusSyncFollowGroup.Error {
    init(from error: Swift.Error) {
        if let authError = error as? AuthenticatedActionError {
            self = switch authError {
            case .userNotAuthenticated:        .notConnected
            case .noNetwork:                   .noNetwork
            case let .serverError(serverError): .server(serverError)
            case let .other(wrapped):          .other(wrapped)
            }
        } else {
            self = .other(error)
        }
    }
}
