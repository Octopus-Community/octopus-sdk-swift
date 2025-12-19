//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct StorableProfile: Sendable {
    let id: String
    let nickname: String?
    let bio: String?
    let pictureUrl: URL?

    let tags: ProfileTags

    let totalMessages: Int?
    let accountCreationDate: Date?

    let gamificationLevel: Int?

    let descPostFeedId: String
    let ascPostFeedId: String
}

extension StorableProfile {
    init(from entity: PublicProfileEntity) {
        id = entity.profileId
        nickname = entity.nickname
        bio = entity.bio
        pictureUrl = entity.pictureUrl
        tags = entity.tags
        totalMessages = entity.totalMessages
        accountCreationDate = entity.accountCreationDate
        gamificationLevel = entity.gamificationLevel
        descPostFeedId = entity.descPostFeedId
        ascPostFeedId = entity.ascPostFeedId
    }

    init(from profile: Com_Octopuscommunity_PublicProfile) {
        id = profile.id
        nickname = profile.hasNickname ? profile.nickname.nilIfEmpty : nil
        bio = profile.bio
        pictureUrl = profile.hasPictureURL ? URL(string: profile.pictureURL) : nil

        tags = ProfileTags(from: profile.tags)

        totalMessages = profile.hasTotalMessages ? Int(profile.totalMessages) : nil
        accountCreationDate = profile.hasAccountCreatedAt ? Date(timestampMs: profile.accountCreatedAt) : nil

        gamificationLevel = profile.hasGamificationScore ? Int(profile.gamificationScore.level) : nil

        descPostFeedId = profile.descPostFeedID
        ascPostFeedId = profile.ascPostFeedID
    }
}
