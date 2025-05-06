//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

enum MainFlowScreen: NBScreen {
    case currentUserProfile
    case publicProfile(profileId: String)
    case postDetail(postId: String, scrollToMostRecentComment: Bool)
    case commentDetail(commentId: String, reply: Bool, replyToScrollTo: String?)
    case reportContent(contentId: String)
    case reportProfile(profileId: String)
    case editProfile(bioFocused: Bool, pictureFocused: Bool)
    case settingsList
    case settingsAccount
    case settingsAbout
    case settingsHelp
    case reportExplanation
    case deleteAccount
}
