//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct Profile: Equatable, Sendable {
    // Public so OctopusUI / Octopus can read the resolved Octopus id of a member fetched by client
    // user id (Unified Profile, OCT-1374). Matches the already-public `CurrentUserProfile.id`.
    public let id: String
    public let nickname: String?
    public let bio: String?
    public let pictureUrl: URL?

    public let tags: ProfileTags

    public let totalMessages: Int?
    public let accountCreationDate: Date?
    public let gamificationLevel: GamificationLevel?
    /// The member's id in the host app's own system (Unified Profile). Non-nil only when the community
    /// exposes client user ids (`CommunityConfig.exposeClientUserId`) and the member has one — absent
    /// for Octopus-auth users, guests and BO/admin-created profiles. Defaults to `nil`.
    public let clientUserId: String?

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
        clientUserId = storableProfile.clientUserId
        newestFirstPostsFeed = postFeedsStore.getOrCreate(feedId: storableProfile.descPostFeedId)
    }
}
