//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct OctoNotification {
    public enum Thumbnail: Equatable {
        case profile(MinimalProfile)
    }
    public enum Action: Equatable {
        public struct ContentToOpen: Equatable {
            public enum Kind: Equatable, CaseIterable {
                case post
                case comment
                case reply
            }

            public let contentId: String
            public let kind: Kind
        }

        case open([ContentToOpen])
    }
    public let uuid: String
    public let updateDate: Date
    public let isRead: Bool
    public let text: String
    public let thumbnails: [Thumbnail]
    let openAction: String?

    public var action: Action? {
        guard let openAction, let contentToOpen: [Action.ContentToOpen] = .init(from: openAction) else {
            return nil
        }
        return .open(contentToOpen)
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
            openAction = notif.action.link.compactMap { link -> Action.ContentToOpen? in
                guard let kind = Action.ContentToOpen.Kind(from: Int16(link.content.rawValue)) else { return nil }
                return Action.ContentToOpen(contentId: link.octoObjectID, kind: kind)
            }.toStorableString
        } else {
            openAction = nil
        }
    }
}

extension OctoNotification.Action.ContentToOpen.Kind {
    init?(from octoObjectType: Int16) {
        switch octoObjectType {
        case 2: self = .post
        case 3: self = .comment
        case 4: self = .reply
        default: return nil
        }
    }

    init?(from storableName: String) {
        guard let value = Self.allCases.first(where: { $0.storableName == storableName }) else { return nil }
        self = value
    }

    var storableName: String {
        switch self {
        case .post: "post"
        case .comment: "comment"
        case .reply: "reply"
        }
    }
}

private extension Array where Element == OctoNotification.Action.ContentToOpen {
    init?(from storedString: String) {
        guard let storedString = storedString.nilIfEmpty else { return nil }
        self = storedString
            .split(separator: "/")
            .compactMap { aContentToOpen -> OctoNotification.Action.ContentToOpen?  in
                let parts = aContentToOpen.split(separator: ":")
                guard parts.count == 2,
                      let kind = OctoNotification.Action.ContentToOpen.Kind(from: String(parts[0])) else { return nil }
                return OctoNotification.Action.ContentToOpen(contentId: String(parts[1]), kind: kind)
            }
    }

    var toStorableString: String {
        map { "\($0.kind.storableName):\($0.contentId)" }.joined(separator: "/")
    }
}
