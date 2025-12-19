//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct CurrentUserProfile: Equatable, Sendable {
    public let id: String
    let userId: String
    public let nickname: String
    let originalNickname: String?
    public let email: String?
    public let bio: String?
    public let pictureUrl: URL?

    public let tags: ProfileTags

    public let totalMessages: Int?
    public let accountCreationDate: Date?
    public let gamificationLevel: GamificationLevel?
    public let gamificationScore: Int?

    public let hasSeenOnboarding: Bool
    public let hasAcceptedCgu: Bool
    public let hasConfirmedNickname: Bool
    public let hasConfirmedBio: Bool
    public let hasConfirmedPicture: Bool
    public let isGuest: Bool

    public let notificationBadgeCount: Int

    public let blockedProfileIds: [String]

    public let newestFirstPostsFeed: Feed<Post, Comment>
}

extension CurrentUserProfile {
    init(storableProfile: StorableCurrentUserProfile, gamificationLevels: [GamificationLevel],
         postFeedsStore: PostFeedsStore) {
        id = storableProfile.id
        userId = storableProfile.userId
        nickname = storableProfile.nickname
        originalNickname = storableProfile.originalNickname
        email = storableProfile.email
        bio = storableProfile.bio?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        pictureUrl = storableProfile.pictureUrl
        tags = storableProfile.tags
        
        totalMessages = storableProfile.totalMessages
        accountCreationDate = storableProfile.accountCreationDate
        gamificationLevel = gamificationLevels.first { $0.level == storableProfile.gamificationLevel }
        gamificationScore = storableProfile.gamificationScore

        // if frictionless values are nil, it means that we are currently using a non-frictionless profile
        // In this case, default to true values to avoid presenting screens/making actions on this
        // non-frictionless user
        hasSeenOnboarding = storableProfile.hasSeenOnboarding ?? true
        hasAcceptedCgu = storableProfile.hasAcceptedCgu ?? true
        hasConfirmedNickname = storableProfile.hasConfirmedNickname ?? true
        hasConfirmedBio = storableProfile.hasConfirmedBio ?? true
        hasConfirmedPicture = storableProfile.hasConfirmedPicture ?? true
        isGuest = storableProfile.isGuest
        notificationBadgeCount = storableProfile.notificationBadgeCount ?? 0
        blockedProfileIds = storableProfile.blockedProfileIds
        newestFirstPostsFeed = postFeedsStore.getOrCreate(feedId: storableProfile.descPostFeedId)
    }
}
