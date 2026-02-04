//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

struct StorablePost: StorableContent, Equatable {
    let uuid: String
    let text: TranslatableText
    let medias: [Media]
    let poll: Poll?
    let author: MinimalProfile?
    let creationDate: Date
    let updateDate: Date
    let status: StorableStatus
    let statusReasons: [StorableStatusReason]
    let parentId: String
    let descCommentFeedId: String?
    let ascCommentFeedId: String?
    let bridgeClientObjectId: String?
    let bridgeCatchPhrase: TranslatableText?
    let bridgeCtaText: TranslatableText?
    let customActionText: TranslatableText?
    let customActionTargetLink: String?

    let aggregatedInfo: AggregatedInfo?
    let userInteractions: UserInteractions?
}

extension StorablePost {
    init(from entity: PostEntity) {
        uuid = entity.uuid
        text = TranslatableText(originalText: entity.text, originalLanguage: entity.originalLanguage,
                                translatedText: entity.translatedText)
        medias = entity.medias.compactMap { Media(from: $0) }
        poll = Poll(from: entity.pollOptions)
        author = MinimalProfile(from: entity)
        creationDate = Date(timeIntervalSince1970: entity.creationTimestamp)
        updateDate = Date(timeIntervalSince1970: entity.updateTimestamp)
        status = StorableStatus(rawValue: entity.statusValue)
        statusReasons = .init(storableCodes: entity.statusReasonCodes, storableMessages: entity.statusReasonMessages)
        parentId = entity.parentId
        bridgeClientObjectId = entity.clientObjectId
        bridgeCatchPhrase = TranslatableText(originalText: entity.catchPhrase, originalLanguage: entity.originalLanguage,
                                             translatedText: entity.translatedCatchPhrase)
        bridgeCtaText = TranslatableText(originalText: entity.ctaText, originalLanguage: entity.originalLanguage,
                                         translatedText: entity.translatedCtaText)
        customActionText = TranslatableText(originalText: entity.customActionText,
                                            originalLanguage: entity.originalLanguage,
                                            translatedText: entity.customActionTranslatedText)
        customActionTargetLink = entity.customActionTargetLink

        descCommentFeedId = entity.descChildrenFeedId
        ascCommentFeedId = entity.ascChildrenFeedId
        aggregatedInfo = AggregatedInfo(from: entity)
        userInteractions = UserInteractions(from: entity)
    }

    init?(octoPost: Com_Octopuscommunity_OctoObject, aggregate: Com_Octopuscommunity_Aggregate?,
          userInteraction: Com_Octopuscommunity_RequesterCtx?) {
        guard (octoPost.hasContent && octoPost.content.hasPost) || octoPost.status.value != .published else {
            return nil
        }
        uuid = octoPost.id
        let post = octoPost.content.post
        text = TranslatableText(originalText: post.text, originalLanguage: post.originalLanguage.nilIfEmpty,
                                translatedText: post.translatedText.nilIfEmpty)
        if post.hasMedia {
            var mutableMedias = [Media]()
            if post.media.hasVideo, let videoMedia = Media(from: post.media.video) {
                mutableMedias.append(videoMedia)
            }
            mutableMedias.append(contentsOf: post.media.images.compactMap { Media(from: $0) })

            medias = mutableMedias
        } else {
            medias = []
        }
        if post.hasPoll {
            poll = Poll(from: post.poll)
        } else {
            poll = nil
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

        let bridgeInfo = post.hasBridgeToClientObject ? post.bridgeToClientObject : nil
        bridgeClientObjectId = bridgeInfo?.clientObjectID
        bridgeCatchPhrase = (bridgeInfo?.hasCatchPhrase ?? false) ?
            TranslatableText(originalText: bridgeInfo?.catchPhrase, originalLanguage: post.originalLanguage.nilIfEmpty,
                             translatedText: bridgeInfo?.translatedCatchPhrase)
            : nil
        bridgeCtaText = (bridgeInfo?.hasCta ?? false) ?
            TranslatableText(originalText: bridgeInfo?.cta.text, originalLanguage: post.originalLanguage.nilIfEmpty,
                             translatedText: bridgeInfo?.cta.translatedText)
            : nil

        customActionText = post.hasCta ?
            TranslatableText(originalText: post.cta.text, originalLanguage: post.originalLanguage.nilIfEmpty,
                             translatedText: post.cta.translatedText)
            : nil
        customActionTargetLink = (post.hasCta && post.cta.hasTargetLink) ? post.cta.targetLink.nilIfEmpty : nil

        self.aggregatedInfo = aggregate.map { .init(from: $0) }
        self.userInteractions = userInteraction.map { .init(from: $0) }
    }

    init(from post: Post) {
        uuid = post.uuid
        text = post.text
        medias = post.medias
        poll = post.poll
        author = post.author
        creationDate = post.creationDate
        updateDate = post.updateDate
        status = post.innerStatus
        statusReasons = post.innerStatusReasons
        parentId = post.parentId
        bridgeClientObjectId = post.clientObjectBridgeInfo?.objectId
        bridgeCatchPhrase = post.clientObjectBridgeInfo?.catchPhrase
        bridgeCtaText = post.clientObjectBridgeInfo?.ctaText
        customActionText = post.customAction?.ctaText
        customActionTargetLink = post.customAction?.targetUrl.absoluteString

        descCommentFeedId = post.newestFirstCommentsFeed?.id
        ascCommentFeedId = post.oldestFirstCommentsFeed?.id

        aggregatedInfo = post.aggregatedInfo
        userInteractions = post.userInteractions
    }
}
