//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

struct StorableProfile: Sendable {
    let id: String
    let nickname: String?
    let bio: String?
    let pictureUrl: URL?
    let descPostFeedId: String
    let ascPostFeedId: String
}

extension StorableProfile {
    init(from entity: PublicProfileEntity) {
        id = entity.profileId
        nickname = entity.nickname
        bio = entity.bio
        pictureUrl = entity.pictureUrl
        descPostFeedId = entity.descPostFeedId
        ascPostFeedId = entity.ascPostFeedId
    }

    init(from profile: Com_Octopuscommunity_PublicProfile) {
        id = profile.id
        nickname = profile.hasNickname ? profile.nickname.nilIfEmpty : nil
        bio = profile.bio
        pictureUrl = profile.hasPictureURL ? URL(string: profile.pictureURL) : nil
        descPostFeedId = profile.descPostFeedID
        ascPostFeedId = profile.ascPostFeedID
    }
}
