//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .screenDisplayed
    public protocol ScreenDisplayedContext: Sendable {
        /// The screen that has been displayed
        var screen: Screen { get }
    }

    /// A screen
    public enum Screen: Sendable {
        /// The posts feed (i.e. list of posts)
        case postsFeed(PostsFeedContext)
        /// The post detail screen with the list of comments
        case postDetail(PostDetailContext)
        /// The comment detail screen with the list of replies
        case commentDetail(CommentDetailContext)
        /// The create post screen
        case createPost
        /// The user profile screen
        case profile
        /// The profile screen of another Octopus user
        case otherUserProfile(OtherUserProfileContext)
        /// The edit profile screen
        case editProfile
        /// The report content screen
        case reportContent
        /// The report profile screen
        case reportProfile
        /// The validate nickname screen (displayed after a user with a non-modified nickname has created a post)
        case validateNickname
        /// The settings screen
        case settingsList
        /// The account settings screen.
        /// Only visible if the SDK is configured in Octopus authentication (not SSO)
        case settingsAccount
        /// The about settings screen
        case settingsAbout
        /// The report explanation screen
        case reportExplanation
        /// The delete account screen.
        /// Only visible if the SDK is configured in Octopus authentication (not SSO)
        case deleteAccount
    }
}

extension OctopusEvent.Screen {
    /// Context of the otherUserProfile Screen
    public protocol OtherUserProfileContext: Sendable {
        /// The id of the profile that is displayed
        var profileId: String { get }
    }

    /// Context of the postsFeed Screen
    public protocol PostsFeedContext: Sendable {
        /// The id of the feed that is displayed
        var feedId: String { get }
        /// The id to the topic that is related to this feed. Nil if the feed is not representing a topic or is
        /// multi-topic (for example, the feed "For You").
        var relatedTopicId: String? { get }
    }

    /// Context of the postDetail Screen
    public protocol PostDetailContext: Sendable {
        /// The id of the post that is displayed
        var postId: String  { get }
    }

    /// Context of the commentDetail Screen
    public protocol CommentDetailContext: Sendable {
        /// The id of the comment that is displayed
        var commentId: String  { get }
    }
}

extension SdkEvent.ScreenDisplayedContext: OctopusEvent.ScreenDisplayedContext {
    public var screen: OctopusEvent.Screen { .init(from: self) }
}

extension OctopusEvent.Screen {
    init(from kind: SdkEvent.ScreenDisplayedContext) {
        self = switch kind {
        case let .postsFeed(context): .postsFeed(context)
        case let .postDetail(context): .postDetail(context)
        case let .commentDetail(context): .commentDetail(context)
        case .createPost: .createPost
        case .profile: .profile
        case let .otherUserProfile(context): .otherUserProfile(context)
        case .editProfile: .editProfile
        case .reportContent: .reportContent
        case .reportProfile: .reportProfile
        case .validateNickname: .validateNickname
        case .settingsList: .settingsList
        case .settingsAccount: .settingsAccount
        case .settingsAbout: .settingsAbout
        case .reportExplanation: .reportExplanation
        case .deleteAccount: .deleteAccount
        }
    }
}

extension SdkEvent.ScreenDisplayedContext.OtherUserProfileContext: OctopusEvent.Screen.OtherUserProfileContext { }
extension SdkEvent.ScreenDisplayedContext.PostsFeedContext: OctopusEvent.Screen.PostsFeedContext { }
extension SdkEvent.ScreenDisplayedContext.CommentDetailContext: OctopusEvent.Screen.CommentDetailContext { }
extension SdkEvent.ScreenDisplayedContext.PostDetailContext: OctopusEvent.Screen.PostDetailContext { }
