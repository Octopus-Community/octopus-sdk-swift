//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// Per-content-type creation and post navigation options for the current community, driven by the community
/// configuration. Each creation flag governs whether members can use a creation affordance (picture / poll).
///
/// Highest-priority invariant: an absent config — or an absent field — keeps today's behaviour. Creation flags
/// default to `true`; the post tap options default to `false`.
public struct ContentOptions: Equatable, Sendable, Hashable {
    public struct PostOptions: Equatable, Sendable, Hashable {
        public let enablePictures: Bool
        public let enablePolls: Bool
        /// Whether a post must carry text. When `false`, a post that carries an image (with or without a
        /// poll) may be published without text; as soon as it has text, the usual length rules apply.
        public let textRequired: Bool
        /// Whether tapping an image of a post in a feed opens the post, like tapping the card does, instead of
        /// showing the image fullscreen. Only when the card opens the post detail: otherwise, and in the post
        /// detail, images still open fullscreen. Defaults to `false`.
        public let imageTapOpensPost: Bool
        /// Whether tapping the group name of a post, in a feed or in the post detail, opens that group. A member
        /// without access to the group gets the same access-denied flow as from the groups list. Defaults to
        /// `false`: the group name keeps the card action in feeds and does nothing in the post detail.
        public let groupNameTapOpensGroup: Bool

        public init(enablePictures: Bool, enablePolls: Bool, textRequired: Bool = true,
                    imageTapOpensPost: Bool = false, groupNameTapOpensGroup: Bool = false) {
            self.enablePictures = enablePictures
            self.enablePolls = enablePolls
            self.textRequired = textRequired
            self.imageTapOpensPost = imageTapOpensPost
            self.groupNameTapOpensGroup = groupNameTapOpensGroup
        }
    }

    public struct CommentOptions: Equatable, Sendable, Hashable {
        public let enablePictures: Bool

        public init(enablePictures: Bool) {
            self.enablePictures = enablePictures
        }
    }

    public struct ReplyOptions: Equatable, Sendable, Hashable {
        public let enablePictures: Bool

        public init(enablePictures: Bool) {
            self.enablePictures = enablePictures
        }
    }

    public let post: PostOptions
    public let comment: CommentOptions
    public let reply: ReplyOptions

    public init(post: PostOptions, comment: CommentOptions, reply: ReplyOptions) {
        self.post = post
        self.comment = comment
        self.reply = reply
    }

    /// Default when the community sets no content options: everything enabled, post text required and the
    /// original post taps (today's behaviour).
    public static let allEnabled = ContentOptions(
        post: .init(enablePictures: true, enablePolls: true, textRequired: true,
                    imageTapOpensPost: false, groupNameTapOpensGroup: false),
        comment: .init(enablePictures: true),
        reply: .init(enablePictures: true))
}

extension ContentOptions {
    init(from proto: Com_Octopuscommunity_ContentOptions) {
        // proto3 bool defaults to false, but the product default is `true`: read the value only when
        // the field is explicitly present, otherwise fall back to `true`. Same for absent sub-messages.
        // The tap options default to `false`, which is also the proto3 default: an absent field reads `false`.
        post = PostOptions(
            enablePictures: proto.hasPost ? (proto.post.hasEnablePictures ? proto.post.enablePictures : true) : true,
            enablePolls: proto.hasPost ? (proto.post.hasEnablePolls ? proto.post.enablePolls : true) : true,
            textRequired: proto.hasPost ? (proto.post.hasTextRequired ? proto.post.textRequired : true) : true,
            imageTapOpensPost: proto.hasPost && proto.post.imageTapOpensPost,
            groupNameTapOpensGroup: proto.hasPost && proto.post.groupNameTapOpensGroup)
        comment = CommentOptions(
            enablePictures: proto.hasComment
                ? (proto.comment.hasEnablePictures ? proto.comment.enablePictures : true) : true)
        reply = ReplyOptions(
            enablePictures: proto.hasReply
                ? (proto.reply.hasEnablePictures ? proto.reply.enablePictures : true) : true)
    }

    init(from entity: CommunityConfigEntity) {
        post = PostOptions(enablePictures: entity.postEnablePictures,
                           enablePolls: entity.postEnablePolls,
                           textRequired: entity.postTextRequired,
                           imageTapOpensPost: entity.postImageTapOpensPost,
                           groupNameTapOpensGroup: entity.postGroupNameTapOpensGroup)
        comment = CommentOptions(enablePictures: entity.commentEnablePictures)
        reply = ReplyOptions(enablePictures: entity.replyEnablePictures)
    }
}
