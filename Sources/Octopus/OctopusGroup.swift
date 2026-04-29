//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A group.
///
/// A post is related to exactly one group.
public struct OctopusGroup: Equatable, Sendable {
    /// Id of the group
    public let id: String
    /// Name of the group
    public let name: String
    /// Whether the connected user currently follows this group.
    public let isFollowed: Bool
    /// Whether the connected user can change their follow status on this group.
    /// `false` for essential/force-followed groups controlled by community admins.
    public let canChangeFollowStatus: Bool
}

extension OctopusGroup {
    init(from topic: OctopusCore.Topic) {
        self.id = topic.uuid
        self.name = topic.name
        self.isFollowed = topic.isFollowed
        self.canChangeFollowStatus = topic.canChangeFollowStatus
    }
}

/// A topic.
@available(*, deprecated, renamed: "OctopusGroup")
public typealias Topic = OctopusGroup
