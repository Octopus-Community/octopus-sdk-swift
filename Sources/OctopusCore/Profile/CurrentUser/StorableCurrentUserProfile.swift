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
    /// See `MinimalProfile.defaultAvatar`. When non-nil, `pictureUrl` is nil.
    let defaultAvatar: DefaultAvatar?
    /// The default the member would get if they removed their picture now: shown in the profile edit preview once
    /// they tap "remove", before saving. Never set together with `defaultAvatar`.
    let defaultAvatarIfPictureRemoved: DefaultAvatar?

    let tags: ProfileTags

    let totalMessages: Int?
    let accountCreationDate: Date?

    let gamificationLevel: Int?
    let gamificationScore: Int?

    let hasSeenOnboarding: Bool?
    let hasAcceptedCgu: Bool?
    let hasConfirmedNickname: Bool?
    let hasConfirmedBio: Bool?
    let hasConfirmedPicture: Bool?
    let isGuest: Bool

    let notificationBadgeCount: Int?

    let descPostFeedId: String
    let ascPostFeedId: String

    let descCommentFeedId: String
    let ascCommentFeedId: String

    let blockedProfileIds: [String]

    let entitlements: Set<String>

    // swiftlint:disable:next function_default_parameter_at_end
    init(id: String, userId: String, nickname: String, originalNickname: String?, email: String?, bio: String?,
         pictureUrl: URL?, tags: ProfileTags,
         totalMessages: Int?, accountCreationDate: Date?,
         gamificationLevel: Int?, gamificationScore: Int?,
         hasSeenOnboarding: Bool?, hasAcceptedCgu: Bool?, hasConfirmedNickname: Bool?,
         hasConfirmedBio: Bool?, hasConfirmedPicture: Bool?,
         isGuest: Bool, notificationBadgeCount: Int?,
         descPostFeedId: String, ascPostFeedId: String,
         descCommentFeedId: String = "", ascCommentFeedId: String = "",
         blockedProfileIds: [String],
         entitlements: Set<String> = [],
         defaultAvatar: DefaultAvatar? = nil,
         defaultAvatarIfPictureRemoved: DefaultAvatar? = nil) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.originalNickname = originalNickname
        self.email = email
        self.bio = bio
        self.pictureUrl = pictureUrl
        self.defaultAvatar = defaultAvatar
        self.defaultAvatarIfPictureRemoved = defaultAvatarIfPictureRemoved
        self.tags = tags
        self.totalMessages = totalMessages
        self.accountCreationDate = accountCreationDate
        self.gamificationLevel = gamificationLevel
        self.gamificationScore = gamificationScore
        self.hasSeenOnboarding = hasSeenOnboarding
        self.hasAcceptedCgu = hasAcceptedCgu
        self.hasConfirmedNickname = hasConfirmedNickname
        self.hasConfirmedBio = hasConfirmedBio
        self.hasConfirmedPicture = hasConfirmedPicture
        self.isGuest = isGuest
        self.notificationBadgeCount = notificationBadgeCount
        self.descPostFeedId = descPostFeedId
        self.ascPostFeedId = ascPostFeedId
        self.descCommentFeedId = descCommentFeedId
        self.ascCommentFeedId = ascCommentFeedId
        self.blockedProfileIds = blockedProfileIds
        self.entitlements = entitlements
    }
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
        defaultAvatar = entity.defaultAvatar
        defaultAvatarIfPictureRemoved = entity.defaultAvatarIfPictureRemoved
        tags = entity.tags
        totalMessages = entity.totalMessages
        accountCreationDate = entity.accountCreationDate
        gamificationLevel = entity.gamificationLevel
        gamificationScore = entity.gamificationScore
        hasSeenOnboarding = entity.hasSeenOnboarding
        hasAcceptedCgu = entity.hasAcceptedCgu
        hasConfirmedNickname = entity.hasConfirmedNickname
        hasConfirmedBio = entity.hasConfirmedBio
        hasConfirmedPicture = entity.hasConfirmedPicture
        isGuest = entity.isGuest
        notificationBadgeCount = entity.notificationBadgeCount
        descPostFeedId = entity.descPostFeedId
        ascPostFeedId = entity.ascPostFeedId
        descCommentFeedId = entity.descCommentFeedId
        ascCommentFeedId = entity.ascCommentFeedId
        blockedProfileIds = entity.blockedProfileIds
        entitlements = entity.entitlements
    }

    init(from profile: Com_Octopuscommunity_PrivateProfile, userId: String) {
        id = profile.id
        self.userId = userId
        nickname = profile.nickname
        originalNickname = profile.originalNickname.nilIfEmpty
        email = profile.email
        bio = profile.bio

        tags = ProfileTags(from: profile.tags)

        totalMessages = profile.hasTotalMessages ? Int(profile.totalMessages) : nil
        accountCreationDate = profile.hasAccountCreatedAt ? Date(timestampMs: profile.accountCreatedAt) : nil

        if profile.hasGamificationScore {
            gamificationLevel = Int(profile.gamificationScore.level)
            gamificationScore = Int(profile.gamificationScore.score)
        } else {
            gamificationLevel = nil
            gamificationScore = nil
        }

        hasSeenOnboarding = profile.hasHasSeenOnboarding_p ? profile.hasSeenOnboarding_p : nil
        hasAcceptedCgu = profile.hasHasAcceptedCgu_p ? profile.hasAcceptedCgu_p : nil
        hasConfirmedNickname = profile.hasHasConfirmedNickname_p ? profile.hasConfirmedNickname_p : nil
        hasConfirmedBio = profile.hasHasConfirmedBio_p ? profile.hasConfirmedBio_p : nil
        hasConfirmedPicture = profile.hasHasConfirmedPicture_p ? profile.hasConfirmedPicture_p : nil
        isGuest = profile.isGuest
        let defaultAvatar = profile.hasDefaultAvatar ? DefaultAvatar(from: profile.defaultAvatar) : nil
        self.defaultAvatar = defaultAvatar
        // Only a preview of what removing the picture gives: it does not replace the picture.
        defaultAvatarIfPictureRemoved = profile.hasDefaultAvatarIfPictureRemoved
            ? DefaultAvatar(from: profile.defaultAvatarIfPictureRemoved) : nil
        // Same rule as MinimalProfile. The server never copies the default image into the member's own profile;
        // this only keeps the rule in one shape.
        pictureUrl = defaultAvatar == nil && profile.hasPictureURL ? URL(string: profile.pictureURL) : nil
        if profile.hasNotSeenNotificationsCount {
            notificationBadgeCount = Int(profile.notSeenNotificationsCount)
        } else {
            notificationBadgeCount = nil
        }
        descPostFeedId = profile.descPostFeedID
        ascPostFeedId = profile.ascPostFeedID
        descCommentFeedId = profile.descCommentFeedID
        ascCommentFeedId = profile.ascCommentFeedID
        blockedProfileIds = profile.usersBlockList
        entitlements = Set(profile.entitlements)
    }
}
