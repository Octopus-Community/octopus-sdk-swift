//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct StorableComment: StorableResponse, Equatable, Sendable {
    let uuid: String
    let text: TranslatableText?
    let medias: [Media]
    let author: MinimalProfile?
    let creationDate: Date
    let updateDate: Date
    let status: StorableStatus
    let statusReasons: [StorableStatusReason]
    let parentId: String
    let descReplyFeedId: String?
    let ascReplyFeedId: String?

    let aggregatedInfo: AggregatedInfo?
    let userInteractions: UserInteractions?
}

extension StorableComment {
    init(from entity: CommentEntity) {
        uuid = entity.uuid
        text = TranslatableText(originalText: entity.text?.nilIfEmpty, originalLanguage: entity.originalLanguage,
                                translatedText: entity.translatedText)
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
        userInteractions = UserInteractions(from: entity)
    }

    init?(octoComment: Com_Octopuscommunity_OctoObject, aggregate: Com_Octopuscommunity_Aggregate?,
          userInteraction: Com_Octopuscommunity_RequesterCtx?) {
        guard octoComment.hasContent && octoComment.content.hasComment else { return nil }
        uuid = octoComment.id
        let comment = octoComment.content.comment
        text = TranslatableText(originalText: comment.text.nilIfEmpty,
                                originalLanguage: comment.originalLanguage.nilIfEmpty,
                                translatedText: comment.translatedText.nilIfEmpty)
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

        self.aggregatedInfo = aggregate.map { .init(from: $0) }
        self.userInteractions = userInteraction.map { .init(from: $0) }
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
