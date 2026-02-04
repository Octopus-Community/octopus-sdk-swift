//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that provides the list of all events emitted by the SDK
class EventsViewModel: ObservableObject {
    struct DisplayableEvent {
        let eventName: String
        let params: [String]
    }
    @Published private(set) var events: [DisplayableEvent] = []

    private var storage = [AnyCancellable]()

    init() {
        TrackingManager.instance.$events.sink { [unowned self] in
            events = $0.map { DisplayableEvent(from: $0) }
        }.store(in: &storage)
    }
}

extension EventsViewModel.DisplayableEvent {
    init(from event: OctopusEvent) {
        switch event {
        case let .postCreated(context):
            eventName = "Post Created"
            var content = [String]()
            if context.content.contains(.text) {
                content.append("Text")
            }
            if context.content.contains(.poll) {
                content.append("Poll")
            }
            if context.content.contains(.image) {
                content.append("Image")
            }
            params = [
                "Id: \(context.postId)",
                "Topic: \(context.topicId)",
                "Text length: \(context.textLength)",
                "Content: \(content.joined(separator: ", "))"
            ]
        case let .commentCreated(context):
            eventName = "Comment Created"
            params = [
                "Id: \(context.commentId)",
                "Post: \(context.postId)",
                "Text length: \(context.textLength)"
            ]
        case let .replyCreated(context):
            eventName = "Reply Created"
            params = [
                "Id: \(context.replyId)",
                "Post: \(context.commentId)",
                "Text length: \(context.textLength)"
            ]
        case let .contentDeleted(context):
            eventName = "Content Deleted"
            params = [
                "Content Id: \(context.contentId)",
                "Content Kind: \(String(describing: context.kind))"
            ]
        case let .reactionModified(context):
            eventName = "Reaction Modified"
            params = [
                "Content Id: \(context.contentId)",
                "Previous Reaction: \(context.previousReaction.map { String(describing: $0) } ?? "-")",
                "New Reaction: \(context.newReaction.map { String(describing: $0) } ?? "-")",
                "Content Kind: \(String(describing: context.contentKind))"
            ]
        case let .pollVoted(context):
            eventName = "Poll Voted"
            params = [
                "Content Id: \(context.contentId)",
                "Option Id: \(context.optionId)"
            ]
        case let .contentReported(context):
            eventName = "Content Reported"
            params = [
                "Content Id: \(context.contentId)",
                "Reasons: \(context.reasons.map { String(describing: $0) }.joined(separator: ", "))"
            ]
        case let .gamificationPointsGained(context):
            eventName = "Gamification Points Gained"
            params = [
                "Action: \(String(describing: context.action))",
                "Points gained: \(context.pointsGained)"
            ]
        case let .gamificationPointsRemoved(context):
            eventName = "Gamification Points Removed"
            params = [
                "Action: \(String(describing: context.action))",
                "Points removed: \(context.pointsRemoved)"
            ]
        case let .screenDisplayed(context):
            switch context.screen {
            case let .postsFeed(context):
                eventName = "Posts Feed Screen Displayed"
                params = [
                    "Feed Id: \(context.feedId)",
                    "Related Topic Id: \(context.relatedTopicId ?? "-")"
                ]
            case let .postDetail(context):
                eventName = "Post Detail Screen Displayed"
                params = [
                    "Post Id: \(context.postId)"
                ]
            case let .commentDetail(context):
                eventName = "Comment Detail Screen Displayed"
                params = [
                    "Comment Id: \(context.commentId)"
                ]
            case .createPost:
                eventName = "Create Post Screen Displayed"
                params = []
            case .profile:
                eventName = "Profile Screen Displayed"
                params = []
            case let .otherUserProfile(context):
                eventName = "Other profile Screen Displayed"
                params = [
                    "Profile Id: \(context.profileId)"
                ]
            case .editProfile:
                eventName = "Edit Profile Screen Displayed"
                params = []
            case .reportContent:
                eventName = "Report Content Screen Displayed"
                params = []
            case .reportProfile:
                eventName = "Report Profile Displayed"
                params = []
            case .validateNickname:
                eventName = "Validate Nickname Screen Displayed"
                params = []
            case .settingsList:
                eventName = "Settings List Screen Displayed"
                params = []
            case .settingsAccount:
                eventName = "Account Settings Screen Displayed"
                params = []
            case .settingsAbout:
                eventName = "About Screen Displayed"
                params = []
            case .reportExplanation:
                eventName = "Report Explanation Screen Displayed"
                params = []
            case .deleteAccount:
                eventName = "Delete Account Screen Displayed"
                params = []
            }
        case let .notificationClicked(context):
            eventName = "Internal Notification Clicked"
            params = [
                "Notification Id: \(context.notificationId)",
                "Content Id: \(context.contentId ?? "-")"
            ]
        case let .postClicked(context):
            eventName = "Post Clicked"
            params = [
                "Post Id: \(context.postId)",
                "Source: \(String(describing: context.source))"
            ]
        case let .translationButtonClicked(context):
            eventName = "Translation Button Clicked"
            params = [
                "Content Id: \(context.contentId)",
                "Content Kind: \(String(describing: context.contentKind))",
                "View Translated: \(context.viewTranslated ? "true" : "false")"
            ]
        case let .commentButtonClicked(context):
            eventName = "Comment Button Clicked"
            params = [
                "Post Id: \(context.postId)"
            ]
        case let .replyButtonClicked(context):
            eventName = "Reply Button Clicked"
            params = [
                "Comment Id: \(context.commentId)"
            ]
        case let .seeRepliesButtonClicked(context):
            eventName = "See Replies Button Clicked"
            params = [
                "Comment Id: \(context.commentId)"
            ]
        case let .profileModified(context):
            eventName = "Profile Modified"
            let nickname = switch context.nickname {
            case .unchanged: "Unchanged"
            case .updated: "Modified"
            }
            let bio = switch context.bio {
            case .unchanged: "Unchanged"
            case let .updated(value): "Modified. New length: \(value.bioLength)"
            }
            let picture = switch context.picture {
            case .unchanged: "Unchanged"
            case let .updated(value): "Modified. Has picture: \(value.hasPicture)"
            }
            params = [
                "Nickname: \(nickname)",
                "Bio: \(bio)",
                "picture: \(picture)"
            ]
        case let .sessionStarted(context):
            eventName = "Session Started"
            params = [
                "Session Id: \(context.sessionId)"
            ]
        case let .sessionStopped(context):
            eventName = "Session Stopped"
            params = [
                "Session Id: \(context.sessionId)"
            ]
        }
    }
}
