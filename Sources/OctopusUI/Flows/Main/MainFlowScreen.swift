//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

enum MainFlowScreen: NBScreen {
    case currentUserProfile
    case publicProfile(profileId: String)
    /// Posts-only "user posts" screen (Unified Profile, OCT-1374). No profile header, no tabs, no
    /// overflow menu. Opened either with a resolved Octopus profile id (in-community profile tap on a
    /// member with no client user id — guest / BO / admin) or with the host's own client user id (the
    /// `OctopusInitialScreen.activity` entry point, resolved asynchronously). See `ActivitySource`.
    case activity(ActivitySource)
    case createPost(withPoll: Bool, defaultTopicId: String?)
    case groupList(context: GroupListContext)
    case groupDetail(groupId: String)
    case postDetail(postId: String, comment: Bool, commentToScrollTo: String?, scrollToMostRecentComment: Bool, origin: PostDetailNavigationOrigin, hasFeaturedComment: Bool)
    case commentDetail(commentId: String, displayGoToParentButton: Bool, reply: Bool, replyToScrollTo: String?)
    case editProfile(bioFocused: Bool, pictureFocused: Bool)
    case settingsAccount
    case reportExplanation
    case deleteAccount
}
