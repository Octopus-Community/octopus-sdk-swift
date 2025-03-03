//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

public struct Comment: Equatable, Sendable {
    public let uuid: String
    public let text: String?
    public let medias: [Media]
    public let author: MinimalProfile?
    public let creationDate: Date
    public let updateDate: Date
    public let parentId: String

    public let aggregatedInfo: AggregatedInfo
    public let userInteractions: UserInteractions

    let innerStatus: StorableStatus
    let innerStatusReasons: [StorableStatusReason]

    public var status: Status {
        Status(status: innerStatus, reasons: innerStatusReasons)
    }

    public var canBeDisplayed: Bool {
        switch status {
        case .published, .other: return true
        case .moderated: return false
        }
    }
}

extension Comment {
    init(from entity: CommentEntity) {
        uuid = entity.uuid
        text = entity.text?.nilIfEmpty
        medias = entity.medias.compactMap { Media(from: $0) }
        author = MinimalProfile(from: entity)
        creationDate = Date(timeIntervalSince1970: Double(entity.creationTimestamp))
        updateDate = Date(timeIntervalSince1970: Double(entity.creationTimestamp))
        innerStatus = StorableStatus(rawValue: entity.statusValue)
        innerStatusReasons = .init(storableCodes: entity.statusReasonCodes,
                                   storableMessages: entity.statusReasonMessages)
        parentId = entity.parentId
        aggregatedInfo = AggregatedInfo(from: entity)
        userInteractions = UserInteractions(userLikeId: entity.userLikeId)
    }

    init?(from octoComment: Com_Octopuscommunity_OctoObject, aggregate: Com_Octopuscommunity_Aggregate?,
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
        innerStatus = StorableStatus(from: octoComment.status.value)
        innerStatusReasons = .init(from: octoComment.status.reasons)
        parentId = octoComment.parentID

        if let aggregate {
            aggregatedInfo = AggregatedInfo(from: aggregate)
        } else {
            aggregatedInfo = .empty
        }

        if let userInteraction {
            userInteractions = .init(from: userInteraction)
        } else {
            userInteractions = .init(userLikeId: nil)
        }
    }
}
