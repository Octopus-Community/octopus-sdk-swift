//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

struct DisplayableNotification: Equatable {
    let uuid: String
    let relativeDate: String
    let isRead: Bool
    let text: String
    let thumbnails: [OctoNotification.Thumbnail]
    let action: NotifAction?
}

extension DisplayableNotification {
    init(notification: OctoNotification, dateFormatter: RelativeDateTimeFormatter) {
        uuid = notification.uuid
        isRead = notification.isRead
        text = notification.text
        thumbnails = notification.thumbnails
        relativeDate = dateFormatter.customLocalizedStructure(for: notification.updateDate, relativeTo: Date())
        action = notification.action
    }
}
