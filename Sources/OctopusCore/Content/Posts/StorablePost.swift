//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

struct StorablePost: StorableContent, Equatable {
    let uuid: String
    let text: String
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
    let clientObjectId: String?
    let catchPhrase: String?
    let ctaText: String?

    let aggregatedInfo: AggregatedInfo?
    let userInteractions: UserInteractions?
}

extension StorablePost {
    init(from entity: PostEntity) {
        uuid = entity.uuid
        text = entity.text
        medias = entity.medias.compactMap { Media(from: $0) }
        poll = Poll(from: entity.pollOptions)
        author = MinimalProfile(from: entity)
        creationDate = Date(timeIntervalSince1970: entity.creationTimestamp)
        updateDate = Date(timeIntervalSince1970: entity.updateTimestamp)
        status = StorableStatus(rawValue: entity.statusValue)
        statusReasons = .init(storableCodes: entity.statusReasonCodes, storableMessages: entity.statusReasonMessages)
        parentId = entity.parentId
        clientObjectId = entity.clientObjectId
        catchPhrase = entity.catchPhrase
        ctaText = entity.ctaText
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
        text = post.text
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
        clientObjectId = bridgeInfo?.clientObjectID
        catchPhrase = (bridgeInfo?.hasCatchPhrase ?? false) ? bridgeInfo?.catchPhrase : nil
        ctaText = (bridgeInfo?.hasCta ?? false) ? bridgeInfo?.cta.text : nil

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
        clientObjectId = post.clientObjectBridgeInfo?.objectId
        catchPhrase = post.clientObjectBridgeInfo?.catchPhrase
        ctaText = post.clientObjectBridgeInfo?.ctaText
        descCommentFeedId = post.newestFirstCommentsFeed?.id
        ascCommentFeedId = post.oldestFirstCommentsFeed?.id

        aggregatedInfo = post.aggregatedInfo
        userInteractions = post.userInteractions
    }
}
