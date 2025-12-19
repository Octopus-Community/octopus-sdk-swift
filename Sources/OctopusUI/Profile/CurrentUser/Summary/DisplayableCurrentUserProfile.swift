//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

struct DisplayableCurrentUserProfile {
    let nickname: String
    let bio: EllipsizableText?
    let pictureUrl: URL?
    let tags: ProfileTags
    let totalMessages: Int?
    let accountCreationDate: Date?
    let gamificationLevel: GamificationLevel?
    let gamificationScore: Int?
}

extension DisplayableCurrentUserProfile {
    init(from profile: CurrentUserProfile) {
        nickname = profile.nickname
        bio = EllipsizableText(text: profile.bio?.cleanedBio, maxLength: 140, maxLines: 2)
        pictureUrl = profile.pictureUrl
        tags = profile.tags
        totalMessages = profile.totalMessages
        accountCreationDate = profile.accountCreationDate
        gamificationLevel = profile.gamificationLevel
        gamificationScore = profile.gamificationScore
    }
}
