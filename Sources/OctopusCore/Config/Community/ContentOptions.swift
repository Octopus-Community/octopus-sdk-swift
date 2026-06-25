//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// Per-content-type creation options for the current community (OCT-1426), driven by the community
/// configuration. Each flag governs whether members can use a creation affordance (picture / poll).
///
/// Highest-priority invariant: every flag defaults to `true`. Absent config — or absent fields —
/// map to `true`, so a community keeps today's behaviour until it is explicitly seeded with `false`.
public struct ContentOptions: Equatable, Sendable, Hashable {
    public struct PostOptions: Equatable, Sendable, Hashable {
        public let enablePictures: Bool
        public let enablePolls: Bool

        public init(enablePictures: Bool, enablePolls: Bool) {
            self.enablePictures = enablePictures
            self.enablePolls = enablePolls
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

    /// Default when the community sets no content options: everything enabled (today's behaviour).
    public static let allEnabled = ContentOptions(
        post: .init(enablePictures: true, enablePolls: true),
        comment: .init(enablePictures: true),
        reply: .init(enablePictures: true))
}

extension ContentOptions {
    init(from proto: Com_Octopuscommunity_ContentOptions) {
        // proto3 bool defaults to false, but the product default is `true`: read the value only when
        // the field is explicitly present, otherwise fall back to `true`. Same for absent sub-messages.
        post = PostOptions(
            enablePictures: proto.hasPost ? (proto.post.hasEnablePictures ? proto.post.enablePictures : true) : true,
            enablePolls: proto.hasPost ? (proto.post.hasEnablePolls ? proto.post.enablePolls : true) : true)
        comment = CommentOptions(
            enablePictures: proto.hasComment
                ? (proto.comment.hasEnablePictures ? proto.comment.enablePictures : true) : true)
        reply = ReplyOptions(
            enablePictures: proto.hasReply
                ? (proto.reply.hasEnablePictures ? proto.reply.enablePictures : true) : true)
    }

    init(from entity: CommunityConfigEntity) {
        post = PostOptions(enablePictures: entity.postEnablePictures, enablePolls: entity.postEnablePolls)
        comment = CommentOptions(enablePictures: entity.commentEnablePictures)
        reply = ReplyOptions(enablePictures: entity.replyEnablePictures)
    }
}
