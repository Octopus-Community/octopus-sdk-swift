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
    /// See `MinimalProfile.defaultAvatar`. When non-nil, `pictureUrl` is nil.
    let defaultAvatar: DefaultAvatar?

    let tags: ProfileTags

    let totalMessages: Int?
    let accountCreationDate: Date?

    let gamificationLevel: Int?

    let descPostFeedId: String
    let ascPostFeedId: String

    let descCommentFeedId: String
    let ascCommentFeedId: String

    let clientUserId: String?
}

extension StorableProfile {
    init(from entity: PublicProfileEntity) {
        id = entity.profileId
        nickname = entity.nickname
        bio = entity.bio
        pictureUrl = entity.pictureUrl
        defaultAvatar = entity.defaultAvatar
        tags = entity.tags
        totalMessages = entity.totalMessages
        accountCreationDate = entity.accountCreationDate
        gamificationLevel = entity.gamificationLevel
        descPostFeedId = entity.descPostFeedId
        ascPostFeedId = entity.ascPostFeedId
        descCommentFeedId = entity.descCommentFeedId
        ascCommentFeedId = entity.ascCommentFeedId
        clientUserId = entity.clientUserId
    }

    init(from profile: Com_Octopuscommunity_PublicProfile) {
        id = profile.id
        nickname = profile.hasNickname ? profile.nickname.nilIfEmpty : nil
        bio = profile.bio
        let defaultAvatar = profile.hasDefaultAvatar ? DefaultAvatar(from: profile.defaultAvatar) : nil
        self.defaultAvatar = defaultAvatar
        // Same rule as MinimalProfile: a default that can be drawn replaces the copy of it made for older SDKs.
        pictureUrl = defaultAvatar == nil && profile.hasPictureURL ? URL(string: profile.pictureURL) : nil

        tags = ProfileTags(from: profile.tags)

        totalMessages = profile.hasTotalMessages ? Int(profile.totalMessages) : nil
        accountCreationDate = profile.hasAccountCreatedAt ? Date(timestampMs: profile.accountCreatedAt) : nil

        gamificationLevel = profile.hasGamificationScore ? Int(profile.gamificationScore.level) : nil

        descPostFeedId = profile.descPostFeedID
        ascPostFeedId = profile.ascPostFeedID

        descCommentFeedId = profile.descCommentFeedID
        ascCommentFeedId = profile.ascCommentFeedID

        clientUserId = profile.hasClientUserID ? profile.clientUserID.nilIfEmpty : nil
    }
}
