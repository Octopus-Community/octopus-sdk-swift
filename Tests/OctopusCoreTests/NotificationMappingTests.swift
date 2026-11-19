//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// `OctoNotification(from:)`: a notification received from the server.
struct NotificationMappingTests {

    @Test func mapsTheScalarFields() {
        let notification = OctoNotification(from: Com_Octopuscommunity_Notification.with {
            $0.id = "NOTIF_ID"
            $0.read = true
            $0.updatedAt = 1_700_000_000_500
            $0.md = "**Alice** commented"
        })

        #expect(notification.uuid == "NOTIF_ID")
        #expect(notification.isRead)
        // `updatedAt` is in milliseconds.
        #expect(notification.updateDate == Date(timeIntervalSince1970: 1_700_000_000.5))
        #expect(notification.text == "**Alice** commented")
    }

    @Test func takesTheTextFromEitherFormat() {
        let raw = OctoNotification(from: Com_Octopuscommunity_Notification.with { $0.raw = "Plain text" })
        let none = OctoNotification(from: Com_Octopuscommunity_Notification())

        #expect(raw.text == "Plain text")
        #expect(none.text == "")
    }

    @Test func keepsOnlyTheThumbnailsThatHaveAProfile() {
        let notification = OctoNotification(from: Com_Octopuscommunity_Notification.with {
            $0.notificationThumbnails = [
                .with { $0.profile = .with { $0.profileID = "PROFILE_1"; $0.nickname = "Alice" } },
                Com_Octopuscommunity_Notification.NotificationThumbnail(),
                .with { $0.profile = .with { $0.profileID = "PROFILE_2"; $0.nickname = "Bob" } }
            ]
        })

        let profiles = notification.thumbnails.map { thumbnail -> MinimalProfile in
            switch thumbnail {
            case let .profile(profile): profile
            }
        }
        #expect(profiles.map(\.uuid) == ["PROFILE_1", "PROFILE_2"])
        #expect(profiles.map(\.nickname) == ["Alice", "Bob"])
    }

    @Test func opensTheLinkedContent() {
        let notification = OctoNotification(from: Com_Octopuscommunity_Notification.with {
            $0.action = .with {
                $0.link = [.with { $0.octoObjectID = "POST_ID"; $0.content = .post }]
            }
        })

        #expect(notification.action == .open(path: [
            .postDetail(postId: "POST_ID", commentToScrollTo: nil, scrollToMostRecentComment: false)
        ]))
    }

    @Test func hasNoActionWithoutALink() {
        let withoutAction = OctoNotification(from: Com_Octopuscommunity_Notification())
        let withEmptyAction = OctoNotification(from: Com_Octopuscommunity_Notification.with {
            $0.action = Com_Octopuscommunity_Notification.Action()
        })
        let withUnknownContent = OctoNotification(from: Com_Octopuscommunity_Notification.with {
            $0.action = .with {
                $0.link = [.with { $0.octoObjectID = "OBJECT_ID"; $0.content = .UNRECOGNIZED(99) }]
            }
        })

        #expect(withoutAction.action == nil)
        #expect(withEmptyAction.action == nil)
        #expect(withUnknownContent.action == nil)
    }
}
