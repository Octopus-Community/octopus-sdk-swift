//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Namespace for the batch-sync-follow-groups feature.
public enum OctopusSyncFollowGroup {

    /// A single follow/unfollow action to sync for a group, with its own timestamp.
    public struct Action: Sendable {
        /// The id of the group to follow or unfollow.
        public let groupId: String
        /// `true` to follow the group, `false` to unfollow.
        public let followed: Bool
        /// The date of the action as observed by the client. The backend compares this
        /// to the stored timestamp for the (user, group) pair and only applies more
        /// recent actions — stale actions are silently returned as ``Status/skipped``.
        /// If a user manually followed/unfollowed the group after the actionDate, this action won't be applied and
        /// ``Status/skipped`` will be returned.
        public let actionDate: Date

        /// Creates a new sync-follow action.
        /// - Parameters:
        ///   - groupId: The id of the group.
        ///   - followed: `true` to follow, `false` to unfollow.
        ///   - actionDate: The date at which the client observed the action.
        public init(groupId: String, followed: Bool, actionDate: Date) {
            self.groupId = groupId
            self.followed = followed
            self.actionDate = actionDate
        }
    }

    /// The per-action outcome returned by the backend.
    public struct Result: Sendable {
        /// The id of the group this result refers to.
        public let groupId: String
        /// The outcome status for the action.
        public let status: Status
    }

    /// The outcome status for a single action inside a sync batch.
    public enum Status: Sendable {
        /// The action was applied by the backend.
        case applied
        /// The action was skipped because a more recent action exists for this (user, group).
        case skipped
        /// No group exists with the given id.
        case groupNotFound
        /// The group is not followable (e.g. admin-restricted).
        case notFollowable
        /// The group cannot be unfollowed (essential/force-followed group).
        case notUnfollowable
        /// The user already follows this group — server state unchanged.
        case alreadyFollowed
        /// The user already does not follow this group — server state unchanged.
        case alreadyUnfollowed
        /// An unclassified server error occurred for this action.
        case unknownError
    }

    /// Errors that can be thrown by ``OctopusSDK/syncFollowGroups(actions:)``.
    public enum Error: Swift.Error, CustomDebugStringConvertible {
        /// No user is connected.
        case notConnected
        /// No network connection is available.
        case noNetwork
        /// A server error occurred.
        case server(Swift.Error)
        /// An unknown error occurred.
        case other(Swift.Error?)

        public var debugDescription: String {
            switch self {
            case .notConnected:
                return "Not connected (OctopusSyncFollowGroup.Error.notConnected)"
            case .noNetwork:
                return "No network (OctopusSyncFollowGroup.Error.noNetwork)"
            case let .server(serverError):
                return "Server error \(String(describing: serverError)) (OctopusSyncFollowGroup.Error.server)"
            case let .other(error):
                return "\(String(describing: error)) (OctopusSyncFollowGroup.Error.other)"
            }
        }
    }
}
