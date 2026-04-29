//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The per-action outcome returned by the SyncFollowTopics RPC.
public struct SyncFollowTopicResult: Sendable, Equatable {
    public let topicId: String
    public let status: Status

    public init(topicId: String, status: Status) {
        self.topicId = topicId
        self.status = status
    }

    /// The outcome status for a single action.
    public enum Status: Sendable, Equatable {
        case applied
        case skipped
        case topicNotFound
        case notFollowable
        case notUnfollowable
        case alreadyFollowed
        case alreadyUnfollowed
        case unknownError
    }
}

extension SyncFollowTopicResult {
    init(from proto: Com_Octopuscommunity_SyncFollowTopicResult) {
        self.topicId = proto.topicID
        self.status = Status(from: proto.status)
    }
}

extension SyncFollowTopicResult.Status {
    init(from proto: Com_Octopuscommunity_SyncFollowTopicStatus) {
        self = switch proto {
        case .syncFollowApplied:           .applied
        case .syncFollowSkipped:           .skipped
        case .syncFollowTopicNotFound:     .topicNotFound
        case .syncFollowNotFollowable:     .notFollowable
        case .syncFollowNotUnfollowable:   .notUnfollowable
        case .syncFollowAlreadyFollowed:   .alreadyFollowed
        case .syncFollowAlreadyUnfollowed: .alreadyUnfollowed
        case .syncFollowError, .syncFollowUnspecified, .UNRECOGNIZED: .unknownError
        }
    }
}
