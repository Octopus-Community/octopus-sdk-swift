//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import os

extension SdkEvent {
    /// A screen
    public enum ScreenDisplayedContext: Sendable {
        case mainFeed(MainFeedContext)
        case groups
        case groupDetail(GroupDetailContext)
        case postDetail(PostDetailContext)
        case commentDetail(CommentDetailContext)
        case createPost
        case profile
        case otherUserProfile(OtherUserProfileContext)
        case editProfile
        case reportContent
        case reportProfile
        case validateNickname
        case settingsList
        case settingsAccount
        case settingsAbout
        case reportExplanation
        case deleteAccount
    }
}

extension SdkEvent.ScreenDisplayedContext {
    /// Context of the otherUserProfile Screen
    public struct OtherUserProfileContext: Sendable {
        /// The id of the profile that is displayed
        public let profileId: String

        public init(profileId: String) {
            self.profileId = profileId
        }

    }

    /// Context of the mainFeed Screen
    public struct MainFeedContext: Sendable {
        /// The id of the feed that is displayed
        public let feedId: String

        public init(feedId: String) {
            self.feedId = feedId
        }
    }

    /// Context of the postDetail Screen
    public struct PostDetailContext: Sendable {
        /// The id of the post that is displayed
        public let postId: String

        public init(postId: String) {
            self.postId = postId
        }
    }

    /// Context of the commentDetail Screen
    public struct CommentDetailContext: Sendable {
        /// The id of the comment that is displayed
        public let commentId: String

        public init(commentId: String) {
            self.commentId = commentId
        }
    }

    /// Context of the event .groupDetail
    public struct GroupDetailContext: Sendable {
        /// The id of the group.
        public let groupId: String

        public init(groupId: String) {
            self.groupId = groupId
        }
    }
}
