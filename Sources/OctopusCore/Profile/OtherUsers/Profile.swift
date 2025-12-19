//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct Profile: Equatable, Sendable {
    let id: String
    public let nickname: String?
    public let bio: String?
    public let pictureUrl: URL?

    public let tags: ProfileTags

    public let totalMessages: Int?
    public let accountCreationDate: Date?
    public let gamificationLevel: GamificationLevel?

    public let newestFirstPostsFeed: Feed<Post, Comment>
}

extension Profile {
    init(storableProfile: StorableProfile, gamificationLevels: [GamificationLevel], postFeedsStore: PostFeedsStore) {
        id = storableProfile.id
        nickname = storableProfile.nickname
        bio = storableProfile.bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        pictureUrl = storableProfile.pictureUrl
        tags = storableProfile.tags
        totalMessages = storableProfile.totalMessages
        accountCreationDate = storableProfile.accountCreationDate
        gamificationLevel = gamificationLevels.first { $0.level == storableProfile.gamificationLevel }
        newestFirstPostsFeed = postFeedsStore.getOrCreate(feedId: storableProfile.descPostFeedId)
    }
}
