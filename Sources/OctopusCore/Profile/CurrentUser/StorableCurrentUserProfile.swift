//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct StorableCurrentUserProfile: Sendable, Equatable {
    let id: String
    let userId: String
    let nickname: String
    let originalNickname: String?
    let email: String?
    let bio: String?
    let pictureUrl: URL?

    let hasSeenOnboarding: Bool?
    let hasAcceptedCgu: Bool?
    let hasConfirmedNickname: Bool?
    let hasConfirmedBio: Bool?
    let hasConfirmedPicture: Bool?
    let isGuest: Bool

    let notificationBadgeCount: Int?

    let descPostFeedId: String
    let ascPostFeedId: String

    let blockedProfileIds: [String]
}

extension StorableCurrentUserProfile {
    init(from entity: PrivateProfileEntity) {
        id = entity.profileId
        userId = entity.userId
        nickname = entity.nickname
        originalNickname = entity.originalNickname?.nilIfEmpty
        email = entity.email
        bio = entity.bio
        pictureUrl = entity.pictureUrl
        hasSeenOnboarding = entity.hasSeenOnboarding
        hasAcceptedCgu = entity.hasAcceptedCgu
        hasConfirmedNickname = entity.hasConfirmedNickname
        hasConfirmedBio = entity.hasConfirmedBio
        hasConfirmedPicture = entity.hasConfirmedPicture
        isGuest = entity.isGuest
        notificationBadgeCount = entity.notificationBadgeCount
        descPostFeedId = entity.descPostFeedId
        ascPostFeedId = entity.ascPostFeedId
        blockedProfileIds = entity.blockedProfileIds
    }

    init(from profile: Com_Octopuscommunity_PrivateProfile, userId: String) {
        id = profile.id
        self.userId = userId
        nickname = profile.nickname
        originalNickname = profile.originalNickname.nilIfEmpty
        email = profile.email
        bio = profile.bio
        hasSeenOnboarding = profile.hasHasSeenOnboarding_p ? profile.hasSeenOnboarding_p : nil
        hasAcceptedCgu = profile.hasHasAcceptedCgu_p ? profile.hasAcceptedCgu_p : nil
        hasConfirmedNickname = profile.hasHasConfirmedNickname_p ? profile.hasConfirmedNickname_p : nil
        hasConfirmedBio = profile.hasHasConfirmedBio_p ? profile.hasConfirmedBio_p : nil
        hasConfirmedPicture = profile.hasHasConfirmedPicture_p ? profile.hasConfirmedPicture_p : nil
        isGuest = profile.isGuest
        pictureUrl = profile.hasPictureURL ? URL(string: profile.pictureURL) : nil
        if profile.hasNotSeenNotificationsCount {
            notificationBadgeCount = Int(profile.notSeenNotificationsCount)
        } else {
            notificationBadgeCount = nil
        }
        descPostFeedId = profile.descPostFeedID
        ascPostFeedId = profile.ascPostFeedID
        blockedProfileIds = profile.usersBlockList
    }
}
