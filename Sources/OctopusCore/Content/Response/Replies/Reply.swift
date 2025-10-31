//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct Reply: Equatable, Sendable {
    public let uuid: String
    public let text: TranslatableText?
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

extension Reply {
    init(storableComment: StorableReply) {
        uuid = storableComment.uuid
        text = storableComment.text
        medias = storableComment.medias
        author = storableComment.author
        creationDate = storableComment.creationDate
        updateDate = storableComment.updateDate
        innerStatus = storableComment.status
        innerStatusReasons = storableComment.statusReasons
        parentId = storableComment.parentId

        aggregatedInfo = storableComment.aggregatedInfo ?? .empty
        userInteractions = storableComment.userInteractions ?? .empty
    }
}
