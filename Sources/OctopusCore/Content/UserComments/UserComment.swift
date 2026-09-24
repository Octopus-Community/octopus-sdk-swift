//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// One entry of the profile "Comments" feed: a comment or reply the member authored, together
/// with the parent context it hangs under. Each authored content is its own entry (no grouping by post).
public struct UserComment: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case comment(Comment)
        case reply(Reply)
    }

    /// The id of the authored comment/reply (the entry's identity).
    public let id: String
    /// The member's own comment or reply.
    public let content: Content
    /// The post the entry ultimately hangs under. `nil` only for a reply whose grandparent post was not
    /// shipped (the reply is still shown under its parent comment).
    public let post: Post?
    /// For a reply: the parent comment it answers. `nil` for a top-level comment.
    public let parentComment: Comment?
}

extension UserComment {
    private typealias Aggregate = Com_Octopuscommunity_Aggregate
    private typealias OctoObject = Com_Octopuscommunity_OctoObject

    /// Builds a profile Comments feed page from a `WithOctoObject` response: resolves each item's parent
    /// context (`UserCommentsResolver`) and maps the octo objects onto the domain models. Items whose own
    /// content can't be decoded are skipped defensively.
    static func list(from response: Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse,
                     commentFeedsStore: CommentFeedsStore,
                     replyFeedsStore: ReplyFeedsStore) -> [UserComment] {
        let aggregatesById = Dictionary(
            (response.aggregates + response.relatedAggregates).map { ($0.itemID, $0.aggregate) },
            uniquingKeysWith: { first, _ in first })

        return UserCommentsResolver.resolve(feed: response.feed, relatedObjects: response.relatedObjects)
            .compactMap {
                UserComment(context: $0, aggregatesById: aggregatesById,
                            commentFeedsStore: commentFeedsStore,
                            replyFeedsStore: replyFeedsStore)
            }
    }

    private init?(context: UserCommentContext, aggregatesById: [String: Aggregate],
                  commentFeedsStore: CommentFeedsStore, replyFeedsStore: ReplyFeedsStore) {
        func makePost(_ octo: OctoObject) -> Post? {
            StorablePost(octoPost: octo, aggregate: aggregatesById[octo.id], userInteraction: nil)
                .map { Post(storablePost: $0, commentFeedsStore: commentFeedsStore, featuredComment: nil) }
        }
        func makeComment(_ octo: OctoObject) -> Comment? {
            StorableComment(octoComment: octo, aggregate: aggregatesById[octo.id], userInteraction: nil)
                .map { Comment(storableComment: $0, replyFeedsStore: replyFeedsStore) }
        }

        switch context {
        case let .comment(item, postObj):
            guard let storableComment = StorableComment(
                    octoComment: item, aggregate: aggregatesById[item.id], userInteraction: nil),
                  let post = makePost(postObj) else { return nil }
            id = item.id
            content = .comment(Comment(storableComment: storableComment, replyFeedsStore: replyFeedsStore))
            self.post = post
            parentComment = nil
        case let .reply(item, commentObj, postObj):
            guard let storableReply = StorableReply(
                    octoReply: item, aggregate: aggregatesById[item.id], userInteraction: nil),
                  let parentComment = makeComment(commentObj) else { return nil }
            id = item.id
            content = .reply(Reply(storableComment: storableReply))
            self.parentComment = parentComment
            post = postObj.flatMap { makePost($0) }
        }
    }
}
