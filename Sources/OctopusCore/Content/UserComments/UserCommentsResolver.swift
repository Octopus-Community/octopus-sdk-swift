//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// A resolved entry of the profile "Comments" feed: a user's comment or reply together with
/// the parent context it hangs under, resolved from `GetFeedWithOctoObjectPageResponse.relatedObjects`.
///
/// This is the raw (`OctoObject`-level) result of correlating feed items with their parents. The feed
/// layer maps it onto the domain models afterwards.
enum UserCommentContext: Equatable {
    typealias OctoObject = Com_Octopuscommunity_OctoObject

    /// A comment the user made on a post.
    case comment(item: OctoObject, post: OctoObject)
    /// A reply the user made to a comment. `post` is the grandparent and may be `nil` when it is not
    /// shipped (e.g. no longer resolvable) — the reply is still shown under its parent comment.
    case reply(item: OctoObject, comment: OctoObject, post: OctoObject?)

    /// The feed item itself (the user's comment or reply).
    var item: OctoObject {
        switch self {
        case let .comment(item, _), let .reply(item, _, _): return item
        }
    }
}

/// Correlates a `userComments` feed page with its parents. Pure — no I/O — so the tricky part
/// (the `parentId` walk + orphan skipping the backend spec calls out) is unit-testable in isolation.
enum UserCommentsResolver {
    typealias OctoObject = Com_Octopuscommunity_OctoObject

    /// Resolves each feed item to its parent context.
    ///
    /// - The parents live in a **separate, deduped** `relatedObjects` list; we index both the related
    ///   objects and the page's own feed items (a reply's parent comment may be in either).
    /// - **comment** → parent is a **post** (one hop). Missing parent ⇒ skip (don't render an orphan).
    /// - **reply** → parent is a **comment** (one hop), whose parent is a **post** (grandparent, may be
    ///   `nil`). Missing parent comment ⇒ skip.
    /// - Anything that is neither a comment nor a reply is dropped (`userComments` only yields those).
    ///
    /// Feed order is preserved (the backend returns the merged comments+replies already sorted by the
    /// item's own date, anti-chronologically).
    static func resolve(feed: [OctoObject], relatedObjects: [OctoObject]) -> [UserCommentContext] {
        let byId = Dictionary(
            (relatedObjects + feed).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })

        return feed.compactMap { item -> UserCommentContext? in
            guard item.hasContent else { return nil }
            if item.content.hasComment {
                guard let post = byId[item.parentID] else { return nil } // parent gone ⇒ skip
                return .comment(item: item, post: post)
            } else if item.content.hasReply {
                guard let comment = byId[item.parentID] else { return nil } // parent gone ⇒ skip
                return .reply(item: item, comment: comment, post: byId[comment.parentID])
            } else {
                return nil // userComments only yields comments & replies
            }
        }
    }
}
