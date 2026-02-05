//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import os

extension SdkEvent {
    /// A screen
    public enum ScreenDisplayedContext: Sendable {
        /// The posts feed (i.e. list of posts)
        case postsFeed(PostsFeedContext)
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

extension SdkEvent.ScreenDisplayedContext/*.Screen*/ {
    /// Context of the otherUserProfile Screen
    public struct OtherUserProfileContext: Sendable {
        /// The id of the profile that is displayed
        public let profileId: String

        public init(profileId: String) {
            self.profileId = profileId
        }

    }

    /// Context of the postsFeed Screen
    public struct PostsFeedContext: Sendable {
        /// The id of the feed that is displayed
        public let feedId: String
        /// The id to the topic that is related to this feed. Nil if the feed is not representing a topic or is
        /// multi-topic (for example, the feed "For You").
        public let relatedTopicId: String?

        public init(feedId: String, relatedTopicId: String?) {
            self.feedId = feedId
            self.relatedTopicId = relatedTopicId
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
}
