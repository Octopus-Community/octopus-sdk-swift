//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public struct MinimalProfile: Equatable, Sendable {
    public let uuid: String
    public let nickname: String
    public let avatarUrl: URL?
    /// What to draw when the member has no picture of their own and the community chose it. When non-nil,
    /// `avatarUrl` is nil.
    public let defaultAvatar: DefaultAvatar?
    public let tags: ProfileTags
    public let gamificationLevel: Int?
    /// The user's id in the host app's own system (Unified Profile). Non-nil only when the community
    /// exposes client user ids (`CommunityConfig.exposeClientUserId`) and the member has one — absent
    /// for Octopus-auth users, guests and BO/admin-created profiles. Defaults to `nil`.
    public let clientUserId: String?

    /// Public constructor, only for SwiftUI previews
    public init(uuid: String, nickname: String,
                avatarUrl: URL? = nil, defaultAvatar: DefaultAvatar? = nil, tags: ProfileTags = [],
                gamificationLevel: Int? = nil, clientUserId: String? = nil) {
        self.uuid = uuid
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.defaultAvatar = defaultAvatar
        self.tags = tags
        self.gamificationLevel = gamificationLevel
        self.clientUserId = clientUserId
    }
}

extension MinimalProfile {
    init?(from entity: OctoObjectEntity) {
        if let author = entity.author {
            self.init(from: author)
            return
        }

        // fallback just in case migration from authorXXX to author in db has not worked
        guard let authorId = entity.authorId?.nilIfEmpty else { return nil }
        self.init(
            uuid: authorId,
            nickname: entity.authorNickname ?? "",
            avatarUrl: entity.authorAvatarUrl,
            tags: [],
            gamificationLevel: nil
        )
    }

    init(from entity: MinimalProfileEntity) {
        uuid = entity.profileId
        nickname = entity.nickname
        avatarUrl = entity.avatarUrl
        defaultAvatar = entity.defaultAvatar
        tags = entity.tags
        gamificationLevel = entity.gamificationLevel >= 0 ? entity.gamificationLevel : nil
        clientUserId = entity.clientUserId
    }

    init(from profile: Com_Octopuscommunity_MinimalProfile) {
        uuid = profile.profileID
        nickname = profile.nickname
        let defaultAvatar = profile.hasDefaultAvatar ? DefaultAvatar(from: profile.defaultAvatar) : nil
        self.defaultAvatar = defaultAvatar
        // With a default, the member has no picture: avatarUrl holds at most a copy of the default image, made for
        // older SDKs. Drop it only when the default can be drawn; otherwise that copy is the best this version has.
        if defaultAvatar == nil, profile.hasAvatarURL, let profileAvatarUrl = profile.avatarURL.nilIfEmpty {
            avatarUrl = URL(string: profileAvatarUrl)
        } else {
            avatarUrl = nil
        }
        tags = ProfileTags(from: profile.tags)
        gamificationLevel = profile.hasGamificationLevel ? Int(profile.gamificationLevel) : nil
        clientUserId = profile.hasClientUserID ? profile.clientUserID.nilIfEmpty : nil
    }
}

extension Optional where Wrapped == MinimalProfile {
    func isBlocked(in list: [String]) -> Bool {
        // do not block deleted user
        guard let profileId = self?.uuid else { return false }
        return list.contains(where: { $0 == profileId })
    }
}
