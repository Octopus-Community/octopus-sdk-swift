//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// A single follow/unfollow action to sync for a topic, with its own timestamp.
public struct SyncFollowTopicAction: Sendable, Equatable {
    public let topicId: String
    public let followed: Bool
    public let actionDate: Date

    public init(topicId: String, followed: Bool, actionDate: Date) {
        self.topicId = topicId
        self.followed = followed
        self.actionDate = actionDate
    }
}

extension Com_Octopuscommunity_SyncFollowTopicAction {
    init(from action: SyncFollowTopicAction) {
        self = .with {
            $0.topicID = action.topicId
            $0.followed = action.followed
            $0.actionTimestamp = Int64(action.actionDate.timeIntervalSince1970 * 1000)
        }
    }
}
