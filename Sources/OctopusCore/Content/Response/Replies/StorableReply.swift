//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct StorableReply: StorableResponse, Equatable, Sendable {
    let uuid: String
    let text: String?
    let medias: [Media]
    let author: MinimalProfile?
    let creationDate: Date
    let updateDate: Date
    let status: StorableStatus
    let statusReasons: [StorableStatusReason]
    let parentId: String

    let aggregatedInfo: AggregatedInfo?
    let userInteractions: UserInteractions?
}

extension StorableReply {
    init(from entity: ReplyEntity) {
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
        aggregatedInfo = AggregatedInfo(from: entity)
        userInteractions = UserInteractions(from: entity)
    }

    init?(octoReply: Com_Octopuscommunity_OctoObject, aggregate: Com_Octopuscommunity_Aggregate?,
          userInteraction: Com_Octopuscommunity_RequesterCtx?) {
        guard octoReply.hasContent && octoReply.content.hasReply else { return nil }
        uuid = octoReply.id
        let reply = octoReply.content.reply
        text = reply.text.nilIfEmpty
        if reply.hasMedia {
            var mutableMedias = [Media]()
            if reply.media.hasVideo, let videoMedia = Media(from: reply.media.video, kind: .video) {
                mutableMedias.append(videoMedia)
            }
            mutableMedias.append(contentsOf: reply.media.images.compactMap { Media(from: $0, kind: .image)})
            medias = mutableMedias
        } else {
            medias = []
        }
        if octoReply.hasCreatedBy {
            author = MinimalProfile(from: octoReply.createdBy)
        } else {
            author = nil
        }
        creationDate = Date(timestampMs: octoReply.createdAt)
        updateDate = Date(timestampMs: octoReply.updatedAt)
        status = StorableStatus(from: octoReply.status.value)
        statusReasons = .init(from: octoReply.status.reasons)
        parentId = octoReply.parentID

        self.aggregatedInfo = aggregate.map { .init(from: $0) }
        self.userInteractions = userInteraction.map { .init(from: $0) }
    }

    init(from reply: Reply) {
        uuid = reply.uuid
        text = reply.text
        medias = reply.medias
        author = reply.author
        creationDate = reply.creationDate
        updateDate = reply.updateDate
        status = reply.innerStatus
        statusReasons = reply.innerStatusReasons
        parentId = reply.parentId

        aggregatedInfo = reply.aggregatedInfo
        userInteractions = reply.userInteractions
    }
}
