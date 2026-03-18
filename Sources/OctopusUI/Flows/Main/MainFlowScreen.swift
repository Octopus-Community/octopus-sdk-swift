//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

enum MainFlowScreen: NBScreen {
    case currentUserProfile
    case publicProfile(profileId: String)
    case createPost(withPoll: Bool, defaultTopic: Topic?)
    case groupList(context: GroupListContext)
    case groupDetail(topic: Topic)
    case postDetail(postId: String, comment: Bool, commentToScrollTo: String?, scrollToMostRecentComment: Bool, origin: PostDetailNavigationOrigin, hasFeaturedComment: Bool)
    case commentDetail(commentId: String, displayGoToParentButton: Bool, reply: Bool, replyToScrollTo: String?)
    case reportContent(contentId: String)
    case reportProfile(profileId: String)
    case editProfile(bioFocused: Bool, pictureFocused: Bool)
    case settingsList
    case settingsAccount
    case settingsAbout
    case reportExplanation
    case deleteAccount
}
