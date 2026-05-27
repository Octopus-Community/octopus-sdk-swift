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
    /// Whether the connected user has access to this group.
    ///
    /// `true` for groups without an access requirement, or when the user holds the required
    /// entitlement. `false` when the group is visible to the user but they cannot open it
    /// (typically a premium/gated group). When `false`, host UI should route taps through
    /// ``OctopusSDK/groupAccessDeniedCallback`` instead of opening the group.
    public let canAccess: Bool
    /// Whether the connected user can create posts in this group.
    ///
    /// `false` for read-only groups (e.g. announcement channels) where posting is restricted
    /// to admins. Host UI should hide or disable post-creation entry points when `false`.
    public let canCreateChildren: Bool
}

extension OctopusGroup {
    init(from topic: OctopusCore.Topic) {
        self.id = topic.uuid
        self.name = topic.name
        self.isFollowed = topic.isFollowed
        self.canChangeFollowStatus = topic.canChangeFollowStatus
        self.canAccess = topic.permissions.canAccess
        self.canCreateChildren = topic.permissions.canCreateChildren
    }
}

/// A topic.
@available(*, deprecated, renamed: "OctopusGroup")
public typealias Topic = OctopusGroup
