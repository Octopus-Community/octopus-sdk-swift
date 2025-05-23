//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct CurrentUserProfile: Equatable, Sendable {
    public let id: String
    let userId: String
    public let nickname: String
    public let email: String?
    public let bio: String?
    public let pictureUrl: URL?
    public let notificationBadgeCount: Int

    public let blockedProfileIds: [String]

    public let newestFirstPostsFeed: Feed<Post>
}

extension CurrentUserProfile {
    init(storableProfile: StorableCurrentUserProfile, postFeedsStore: PostFeedsStore) {
        id = storableProfile.id
        userId = storableProfile.userId
        nickname = storableProfile.nickname
        email = storableProfile.email
        bio = storableProfile.bio
        pictureUrl = storableProfile.pictureUrl
        notificationBadgeCount = storableProfile.notificationBadgeCount ?? 0
        blockedProfileIds = storableProfile.blockedProfileIds
        newestFirstPostsFeed = postFeedsStore.getOrCreate(feedId: storableProfile.descPostFeedId)
    }
}
