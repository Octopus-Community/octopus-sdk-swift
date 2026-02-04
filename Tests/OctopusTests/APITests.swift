//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import UserNotifications
import Testing
import Octopus

@Suite(.disabled("Disabled because we only need that they compile"))
class APITests {
    @Test func testOctopusSDKApi() async throws {
        _ = try OctopusSDK(apiKey: "API_KEY")
    }

    @Test func testConnectionModeSSOWithAssociatedFields() throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(
            appManagedFields: Set(ConnectionMode.SSOConfiguration.ProfileField.allCases),
            loginRequired: { },
            modifyUser: { profile in
                switch profile {
                case .nickname, .bio, .picture: break
                case .none: break
                }
            }
        )
        _ = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))
    }

    @Test func testSdkConfiguration() async throws {
        _ = OctopusSDK.Configuration()
        let configuration = OctopusSDK.Configuration(appManagedAudioSession: true)
        _ = try OctopusSDK(apiKey: "API_KEY", configuration: configuration)
    }

    @Test func testConnectionModeSSOWithoutAssociatedFields() throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(
            loginRequired: { }
        )
        _ = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))
    }

    @Test func testConnectionModeOctopus() throws {
        _ = try OctopusSDK(apiKey: "API_KEY", connectionMode: .octopus(deepLink: "DEEP_LINK"))
    }

    @Test func testConnectUser() async throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(loginRequired: { })
        let octopus = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))

        octopus.connectUser(
            ClientUser(userId: "USER_ID", profile: .init(nickname: "NICKNAME")),
            tokenProvider: {
                try await Task.sleep(nanoseconds: 1)
                return "TOKEN"
            })
    }

    @Test func testDisconnectUser() async throws {
        let ssoConfiguration = ConnectionMode.SSOConfiguration(loginRequired: { })
        let octopus = try OctopusSDK(apiKey: "API_KEY", connectionMode: .sso(ssoConfiguration))

        octopus.disconnectUser()
    }

    @Test func testNotSeenNotificationCount() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        _ = octopus.notSeenNotificationsCount
        _ = octopus.$notSeenNotificationsCount
        try await octopus.updateNotSeenNotificationsCount()
    }

    @Test func testSetPushNotifToken() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        octopus.set(notificationDeviceToken: "")
    }

    @Test func testIsAnOctopusNotification() async throws {
        // Can force unwrap because we only need the test to compile, not to run
        _ = OctopusSDK.isAnOctopusNotification(notification: UNNotification(coder: NSCoder())!) != false
    }

    @Test func testTrackCommunityAccess() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        octopus.track(hasAccessToCommunity: true)
    }

    @Test func testOverrideCommunityAccess() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        try await octopus.overrideCommunityAccess(true)
    }

    @Test func testHasCommunityAccess() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        _ = octopus.hasAccessToCommunity
        _ = octopus.$hasAccessToCommunity
    }


    @Test func testTrackCustomEvent() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        try await octopus.track(customEvent: CustomEvent(name: "evt1"))
        try await octopus.track(customEvent: CustomEvent(
            name: "evt1",
            properties: [
                "p1": CustomEvent.PropertyValue(value: "v1"),
                "p2": .init(value: "v2")
            ]))
    }

    @Test func testClientUserProfileInit() async throws {
        _ = ClientUser.Profile()
        _ = ClientUser.Profile(nickname: "")
        _ = ClientUser.Profile(nickname: "", bio: "")
        _ = ClientUser.Profile(nickname: "", bio: "", picture: nil)
    }

    @Test func testGetOrCreateClientObjectRelatedPostId() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        let clientPost = ClientPost(clientObjectId: "", text: "", attachment: nil, viewClientObjectButtonText: nil,
                                    signature: nil)
        let _: String = try await octopus.getOrCreateClientObjectRelatedPostId(content: clientPost)
    }

    @Test func testFetchOrCreateClientObjectRelatedPost() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        let clientPost = ClientPost(clientObjectId: "", text: "", attachment: nil, viewClientObjectButtonText: nil,
                                    signature: nil)
        let post = try await octopus.fetchOrCreateClientObjectRelatedPost(content: clientPost)
        let _: String = post.id
        let _: Int = post.commentCount
        let _: Int = post.viewCount
        if let reactionCount = post.reactions.first {
            let _: Int = reactionCount.count
            let reaction = reactionCount.reaction
            let _: String = reaction.unicode
        }

        _ = octopus.getClientObjectRelatedPostPublisher(clientObjectId: "").sink { post in
            guard let post else { return }
            let _: String = post.id
            let _: Int = post.commentCount
            let _: Int = post.viewCount
        }
    }

    @Test func testSetDisplayClientObjectCallback() throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        octopus.set(displayClientObjectCallback: { objectId in })
    }

    @Test func testTopics() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        let _: [Topic] = octopus.topics
        _ = octopus.$topics
        try await octopus.fetchTopics()
    }

    @Test func testClientPostInit() async throws {
        _ = ClientPost(clientObjectId: "", text: "", attachment: .distantImage(URL(string: "")!),
                       viewClientObjectButtonText: nil, signature: nil)
        _ = ClientPost(clientObjectId: "", topicId: "", text: "", catchPhrase: "", attachment: .localImage(Data()),
                       viewClientObjectButtonText: nil, signature: nil)
    }

    @Test func testSetOnNavigateToUrlCallback() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        octopus.set(onNavigateToURLCallback: { url in
            _ = url.host
            return .handledByApp
        })
    }

    @Test func testEvents() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        _ = octopus.eventPublisher.sink { event in
            switch event {
            case let .postCreated(context):
                _ = context.content.contains(.text)
                _ = context.content.contains(.poll)
                _ = context.content.contains(.image)
                let _: String = context.postId
                let _: String = context.topicId
                let _: Int = context.textLength
            case let .commentCreated(context):
                let _: String = context.commentId
                let _: String = context.postId
                let _: Int = context.textLength
            case let .replyCreated(context):
                let _: String = context.replyId
                let _: String = context.commentId
                let _: Int = context.textLength
            case let .contentDeleted(context):
                let _: String = context.contentId
                let kind: OctopusEvent.ContentKind = context.kind
                switch kind {
                case .post: break
                case .comment: break
                case .reply: break
                }
            case let .reactionModified(context):
                let _: String = context.contentId
                let previousReaction: OctopusEvent.ReactionKind? = context.previousReaction
                switch previousReaction {
                case .heart: break
                case .joy: break
                case .mouthOpen: break
                case .clap: break
                case .cry: break
                case .rage: break
                case let .unknown(str):
                    let _: String = str
                case .none: break
                }
                let _: OctopusEvent.ReactionKind? = context.newReaction
                let _: OctopusEvent.ContentKind = context.contentKind
            case let .pollVoted(context):
                let _: String = context.contentId
                let _: String = context.optionId
            case let .contentReported(context):
                let _: String = context.contentId
                let _: [OctopusEvent.ReportReason] = context.reasons
            case let .gamificationPointsGained(context):
                let action: OctopusEvent.GamificationPointsGainedAction = context.action
                switch action {
                case .post: break
                case .comment: break
                case .reply: break
                case .reaction: break
                case .vote: break
                case .postCommented: break
                case .profileCompleted: break
                case .dailySession: break
                }
                let _: Int = context.pointsGained
            case let .gamificationPointsRemoved(context):
                let action: OctopusEvent.GamificationPointsRemovedAction = context.action
                switch action {
                case .postDeleted: break
                case .commentDeleted: break
                case .replyDeleted: break
                case .reactionDeleted: break
                }
                let _: Int = context.pointsRemoved
            case let .screenDisplayed(context):
                switch context.screen {
                case let .postsFeed(context):
                    let _: String = context.feedId
                case let .postDetail(context):
                    let _: String = context.postId
                case let .commentDetail(context):
                    let _: String = context.commentId
                case .createPost: break
                case .profile: break
                case let .otherUserProfile(context):
                    let _: String = context.profileId
                case .editProfile: break
                case .reportContent: break
                case .reportProfile: break
                case .validateNickname: break
                case .settingsList: break
                case .settingsAccount: break
                case .settingsAbout: break
                case .reportExplanation: break
                case .deleteAccount: break
                }
            case let .notificationClicked(context):
                let _: String = context.notificationId
                let _: String? = context.contentId
            case let .postClicked(context):
                let _: String = context.postId
                let source: OctopusEvent.PostClickedSource = context.source
                switch source {
                case .feed: break
                case .profile: break
                }
            case let .translationButtonClicked(context):
                let _: String = context.contentId
                let _:OctopusEvent.ContentKind = context.contentKind
                let _: Bool = context.viewTranslated
            case let .commentButtonClicked(context):
                let _: String = context.postId
            case let .replyButtonClicked(context):
                let _: String = context.commentId
            case let .seeRepliesButtonClicked(context):
                let _: String = context.commentId
            case let .profileModified(context):
                let nickname: OctopusEvent.ProfileFieldUpdate<OctopusEvent.NicknameUpdateContext> = context.nickname
                switch nickname {
                case .unchanged: break
                case .updated: break
                }
                let bio: OctopusEvent.ProfileFieldUpdate<OctopusEvent.BioUpdateContext> = context.bio
                switch bio {
                case .unchanged: break
                case let .updated(value):
                    let _: Int = value.bioLength
                }
                let picture: OctopusEvent.ProfileFieldUpdate<OctopusEvent.PictureUpdateContext> = context.picture
                switch picture {
                case .unchanged: break
                case let .updated(value):
                    let _: Bool = value.hasPicture
                }
            case let .sessionStarted(context):
                let _: String = context.sessionId
            case let .sessionStopped(context):
                let _: String = context.sessionId
            }
        }
    }
}
