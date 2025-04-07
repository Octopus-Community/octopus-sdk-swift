//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct StorableComment: StorableResponse, Equatable, Sendable {
    let uuid: String
    let text: String?
    let medias: [Media]
    let author: MinimalProfile?
    let creationDate: Date
    let updateDate: Date
    let status: StorableStatus
    let statusReasons: [StorableStatusReason]
    let parentId: String
    let descReplyFeedId: String?
    let ascReplyFeedId: String?

    let aggregatedInfo: AggregatedInfo
    let userInteractions: UserInteractions
}

extension StorableComment {
    init(from entity: CommentEntity) {
        uuid = entity.uuid
        text = entity.text?.nilIfEmpty
        medias = entity.medias.compactMap { Media(from: $0) }
        author = MinimalProfile(from: entity)
        creationDate = Date(timeIntervalSince1970: Double(entity.creationTimestamp))
        updateDate = Date(timeIntervalSince1970: Double(entity.creationTimestamp))
        status = StorableStatus(rawValue: entity.statusValue)
        statusReasons = .init(storableCodes: entity.statusReasonCodes,
                                   storableMessages: entity.statusReasonMessages)
        parentId = entity.parentId
        descReplyFeedId = entity.descChildrenFeedId
        ascReplyFeedId = entity.ascChildrenFeedId
        aggregatedInfo = AggregatedInfo(from: entity)
        userInteractions = UserInteractions(userLikeId: entity.userLikeId, pollVoteId: nil) // no poll on comments
    }

    init?(octoComment: Com_Octopuscommunity_OctoObject, aggregate: Com_Octopuscommunity_Aggregate?,
          userInteraction: Com_Octopuscommunity_RequesterCtx?) {
        guard octoComment.hasContent && octoComment.content.hasComment else { return nil }
        uuid = octoComment.id
        let comment = octoComment.content.comment
        text = comment.text.nilIfEmpty
        if comment.hasMedia {
            var mutableMedias = [Media]()
            if comment.media.hasVideo, let videoMedia = Media(from: comment.media.video, kind: .video) {
                mutableMedias.append(videoMedia)
            }
            mutableMedias.append(contentsOf: comment.media.images.compactMap { Media(from: $0, kind: .image)})
            medias = mutableMedias
        } else {
            medias = []
        }
        if octoComment.hasCreatedBy {
            author = MinimalProfile(from: octoComment.createdBy)
        } else {
            author = nil
        }
        creationDate = Date(timestampMs: octoComment.createdAt)
        updateDate = Date(timestampMs: octoComment.updatedAt)
        status = StorableStatus(from: octoComment.status.value)
        statusReasons = .init(from: octoComment.status.reasons)

        parentId = octoComment.parentID
        descReplyFeedId = octoComment.descChildrenFeedID
        ascReplyFeedId = octoComment.ascChildrenFeedID

        if let aggregate {
            aggregatedInfo = AggregatedInfo(from: aggregate)
        } else {
            aggregatedInfo = .empty
        }

        if let userInteraction {
            userInteractions = .init(from: userInteraction)
        } else {
            userInteractions = .empty
        }
    }

    init(from comment: Comment) {
        uuid = comment.uuid
        text = comment.text
        medias = comment.medias
        author = comment.author
        creationDate = comment.creationDate
        updateDate = comment.updateDate
        status = comment.innerStatus
        statusReasons = comment.innerStatusReasons
        parentId = comment.parentId
        descReplyFeedId = comment.newestFirstRepliesFeed?.id
        ascReplyFeedId = comment.oldestFirstRepliesFeed?.id

        aggregatedInfo = comment.aggregatedInfo
        userInteractions = comment.userInteractions
    }
}
