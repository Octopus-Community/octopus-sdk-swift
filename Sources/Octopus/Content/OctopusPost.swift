//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A protocol representing an Octopus Post.
public protocol OctopusPost: Sendable {
    /// Id of the post.
    /// This id should be used if you need to display the post (see `OctopusHomeScreen(octopus:postId:)`).
    var id: String { get }
    /// The reaction count. If a reaction kind is missing from this array, it means that the reaction count of this kind
    /// is 0.
    var reactions: [any OctopusReactionCount] { get }
    /// Comment count. This represents the overall number of **comments and replies** to this post.
    var commentCount: Int { get }
    /// The view count for this content.
    var viewCount: Int { get }
    /// The reaction of the current user on this post. Nil if the user did not react to this post.
    var userReaction: OctopusReactionKind? { get }
}

/// Internal conformance of Post to OctopusPost
extension Post: OctopusPost {
    public var reactions: [any OctopusReactionCount] { aggregatedInfo.reactions }
    public var commentCount: Int { aggregatedInfo.childCount }
    public var viewCount: Int { aggregatedInfo.viewCount }
    public var userReaction: OctopusReactionKind? {
        guard let reactionKind = userInteractions.reaction?.kind else { return nil }
        return OctopusReactionKind(from: reactionKind)
    }
}
