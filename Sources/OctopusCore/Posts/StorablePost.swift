//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels
import SwiftProtobuf

struct StorablePost: Equatable {
    let uuid: String
    let headline: String
    let text: String?
    let medias: [Media]
    let author: MinimalProfile?
    let creationDate: Date
    let updateDate: Date
    let status: StorableStatus
    let statusReasons: [StorableStatusReason]
    let parentId: String
    let descCommentFeedId: String?
    let ascCommentFeedId: String?

    let aggregatedInfo: AggregatedInfo?
    let userLikeId: String?
}

extension StorablePost {
    init(from entity: PostEntity) {
        uuid = entity.uuid
        headline = entity.headline
        text = entity.text
        medias = entity.medias.compactMap { Media(from: $0) }
        author = MinimalProfile(from: entity)
        creationDate = Date(timeIntervalSince1970: entity.creationTimestamp)
        updateDate = Date(timeIntervalSince1970: entity.updateTimestamp)
        status = StorableStatus(rawValue: entity.statusValue)
        statusReasons = .init(storableCodes: entity.statusReasonCodes, storableMessages: entity.statusReasonMessages)
        parentId = entity.parentId
        descCommentFeedId = entity.descChildrenFeedId
        ascCommentFeedId = entity.ascChildrenFeedId
        aggregatedInfo = AggregatedInfo(from: entity)
        userLikeId = entity.userLikeId
    }

    init?(octoPost: Com_Octopuscommunity_OctoObject, aggregate: Com_Octopuscommunity_Aggregate?,
          userInteraction: Com_Octopuscommunity_RequesterCtx?) {
        guard (octoPost.hasContent && octoPost.content.hasPost) || octoPost.status.value != .published else {
            return nil
        }
        uuid = octoPost.id
        let post = octoPost.content.post
        headline = post.headline
        text = post.hasText ? post.text.nilIfEmpty : nil
        if post.hasMedia {
            var mutableMedias = [Media]()
            if post.media.hasVideo, let videoMedia = Media(from: post.media.video, kind: .video) {
                mutableMedias.append(videoMedia)
            }
            mutableMedias.append(contentsOf: post.media.images.compactMap { Media(from: $0, kind: .image)})
            medias = mutableMedias
        } else {
            medias = []
        }
        if octoPost.hasCreatedBy {
            author = MinimalProfile(from: octoPost.createdBy)
        } else {
            author = nil
        }
        creationDate = Date(timestampMs: octoPost.createdAt)
        updateDate = Date(timestampMs: octoPost.updatedAt)
        status = StorableStatus(from: octoPost.status.value)
        statusReasons = .init(from: octoPost.status.reasons)

        parentId = octoPost.parentID
        descCommentFeedId = octoPost.descChildrenFeedID
        ascCommentFeedId = octoPost.ascChildrenFeedID

        if let aggregate {
            aggregatedInfo = AggregatedInfo(from: aggregate)
        } else {
            aggregatedInfo = nil
        }

        if let userInteraction, userInteraction.hasLikeID {
            userLikeId = userInteraction.likeID.nilIfEmpty
        } else {
            userLikeId = nil
        }
    }

    init(from post: Post) {
        uuid = post.uuid
        headline = post.headline
        text = post.text
        medias = post.medias
        author = post.author
        creationDate = post.creationDate
        updateDate = post.updateDate
        status = post.innerStatus
        statusReasons = post.innerStatusReasons
        parentId = post.parentId
        descCommentFeedId = post.newestFirstCommentsFeed?.id
        ascCommentFeedId = post.oldestFirstCommentsFeed?.id

        aggregatedInfo = post.aggregatedInfo
        userLikeId = post.userInteractions.userLikeId
    }
}
