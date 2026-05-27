//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

enum MainFlowScreen: NBScreen {
    case currentUserProfile
    case publicProfile(profileId: String)
    case createPost(withPoll: Bool, defaultTopicId: String?)
    case groupList(context: GroupListContext)
    case groupDetail(groupId: String)
    case postDetail(postId: String, comment: Bool, commentToScrollTo: String?, scrollToMostRecentComment: Bool, origin: PostDetailNavigationOrigin, hasFeaturedComment: Bool)
    case commentDetail(commentId: String, displayGoToParentButton: Bool, reply: Bool, replyToScrollTo: String?)
    case editProfile(bioFocused: Bool, pictureFocused: Bool)
    case settingsList
    case settingsAccount
    case settingsAbout
    case reportExplanation
    case deleteAccount
}
