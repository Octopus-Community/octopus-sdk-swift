//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public enum SdkEvent: Sendable {
    // MARK: Community events

    /// Sent when a post has been created by the current user
    case postCreated(PostCreatedContext)
    /// Sent when a comment has been created by the current user
    case commentCreated(CommentCreatedContext)
    /// Sent when a post has been created by the current user
    case replyCreated(ReplyCreatedContext)
    /// Sent when a post, a comment or a reply has been deleted by the current user
    case contentDeleted(ContentDeletedContext)
    /// Sent when a reaction is modified (added, deleted or changed) on a content by the current user
    case reactionModified(ReactionModifiedContext)
    /// Sent when the current user votes for a poll
    case pollVoted(PollVotedContext)
    /// Sent when a content has been reported by the current user
    case contentReported(ContentReportedContext)

    // MARK: Gamification
    /// Sent when the gamification points are gained. Please note that only the points triggered by an in-app action
    /// are reported live.
    case gamificationPointsGained(GamificationPointsGainedContext)
    /// Sent when the gamification points are removed. Please note that only the points triggered by an in-app action
    /// are reported live. For example, if a post of this user gets moderated, you won't receive the information about
    /// points removed.
    case gamificationPointsRemoved(GamificationPointsRemovedContext)

    // MARK: Navigation

    /// Sent when the user navigates to a given screen
    case screenDisplayed(ScreenDisplayedContext)
    /// Sent when the user clicks on an internal notification (from the Octopus Notification Center)
    case notificationClicked(NotificationClickedContext)
    /// Sent when the user clicks on post
    case postClicked(PostClickedContext)
    /// Sent when the user clicks on a translation button
    case translationButtonClicked(TranslationButtonClickedContext)
    /// Sent when the user clicks the comment button of a post
    case commentButtonClicked(CommentButtonClickedContext)
    /// Sent when the user clicks the reply button of a comment
    case replyButtonClicked(ReplyButtonClickedContext)
    /// Sent when the user clicks on the replies button of a comment
    case seeRepliesButtonClicked(SeeRepliesButtonClickedContext)

    // MARK: Profile

    /// Sent when the profile is modified by the user
    case profileModified(ProfileModifiedContext)

    // MARK: Session

    /// Sent when an Octopus UI session is started
    case sessionStarted(SessionStartedContext)
    /// Sent when an Octopus UI session is stopped (call either when the Octopus UI is closed or when the app is put in
    /// background).
    case sessionStopped(SessionStoppedContext)

}
