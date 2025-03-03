//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

struct StorableCurrentUserProfile: Sendable, Equatable {
    let id: String
    let userId: String
    let nickname: String
    let email: String?
    let bio: String?
    let pictureUrl: URL?

    let descPostFeedId: String
    let ascPostFeedId: String

    let blockedProfileIds: [String]
}

extension StorableCurrentUserProfile {
    init(from entity: PrivateProfileEntity) {
        id = entity.profileId
        userId = entity.userId
        nickname = entity.nickname
        email = entity.email
        bio = entity.bio
        pictureUrl = entity.pictureUrl
        descPostFeedId = entity.descPostFeedId
        ascPostFeedId = entity.ascPostFeedId
        blockedProfileIds = entity.blockedProfileIds
    }

    init?(from profile: Com_Octopuscommunity_PrivateProfile, userId: String) {
        guard profile.hasNickname, let profileNickname = profile.nickname.nilIfEmpty else { return nil }
        id = profile.id
        self.userId = userId
        nickname = profileNickname
        email = profile.email
        bio = profile.bio
        pictureUrl = profile.hasPictureURL ? URL(string: profile.pictureURL) : nil
        descPostFeedId = profile.descPostFeedID
        ascPostFeedId = profile.ascPostFeedID
        blockedProfileIds = profile.usersBlockList
    }
}
