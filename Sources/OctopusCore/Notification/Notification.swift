//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct OctoNotification {
    public enum Thumbnail: Equatable {
        case profile(MinimalProfile)
    }
    public let uuid: String
    public let updateDate: Date
    public let isRead: Bool
    public let text: String
    public let thumbnails: [Thumbnail]
    let openAction: String?

    public var action: NotifAction? {
        guard let openAction, let contentToOpen: [NotifAction.OctoScreen] = .init(from: openAction).nilIfEmpty else {
            return nil
        }
        return .open(path: contentToOpen)
    }
}

extension OctoNotification {
    init(from entity: NotificationEntity) {
        uuid = entity.uuid
        updateDate = Date(timeIntervalSince1970: entity.updateTimestamp)
        isRead = entity.isRead
        text = entity.text
        thumbnails = entity.thumbnails.map {
            .profile(MinimalProfile(from: $0))
        }
        openAction = entity.openAction
    }

    init(from notif: Com_Octopuscommunity_Notification) {
        uuid = notif.id
        updateDate = Date(timestampMs: notif.updatedAt)
        isRead = notif.read
        text = switch notif.text {
        case .md(let md): md
        case .raw(let raw): raw
        default: ""
        }
        thumbnails = notif.notificationThumbnails.compactMap {
            guard $0.hasProfile else { return nil }
            return .profile(MinimalProfile(from: $0.profile))
        }

        if notif.hasAction, !notif.action.link.isEmpty {
            openAction = notif.action.link.storableString
        } else {
            openAction = nil
        }
    }
}
