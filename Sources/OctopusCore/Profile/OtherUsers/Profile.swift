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

    public let newestFirstPostsFeed: Feed<Post>
}

extension Profile {
    init(storableProfile: StorableProfile, postFeedsStore: PostFeedsStore) {
        id = storableProfile.id
        nickname = storableProfile.nickname
        bio = storableProfile.bio
        pictureUrl = storableProfile.pictureUrl
        newestFirstPostsFeed = postFeedsStore.getOrCreate(feedId: storableProfile.descPostFeedId)
    }
}
