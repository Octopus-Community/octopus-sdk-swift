//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
@testable import OctopusCore

extension StorableCurrentUserProfile {
    static func create(
        id: String, userId: String, nickname: String, originalNickname: String? = nil, email: String? = nil,
        bio: String? = nil, pictureUrl: URL? = nil,
        hasSeenOnboarding: Bool? = true, hasAcceptedCgu: Bool? = true,
        hasConfirmedNickname: Bool? = true, hasConfirmedBio: Bool? = true, hasConfirmedPicture: Bool? = true,
        isGuest: Bool = false,
        notificationBadgeCount: Int? = nil,
        descPostFeedId: String = "", ascPostFeedId: String = "", blockedProfileIds: [String] = [])
    -> StorableCurrentUserProfile {
        StorableCurrentUserProfile(
            id: id, userId: userId, nickname: nickname, originalNickname: originalNickname, email: email, bio: bio,
            pictureUrl: pictureUrl, hasSeenOnboarding: hasSeenOnboarding, hasAcceptedCgu: hasAcceptedCgu,
            hasConfirmedNickname: hasConfirmedNickname, hasConfirmedBio: hasConfirmedBio,
            hasConfirmedPicture: hasConfirmedPicture,
            isGuest: isGuest,
            notificationBadgeCount: notificationBadgeCount,
            descPostFeedId: descPostFeedId, ascPostFeedId: ascPostFeedId, blockedProfileIds: blockedProfileIds)
    }
}
