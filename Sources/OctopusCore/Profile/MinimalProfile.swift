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
}

extension MinimalProfile {
    init?(from entity: OctoObjectEntity) {
        guard let authorId = entity.authorId?.nilIfEmpty else { return nil }
        uuid = authorId
        nickname = entity.authorNickname ?? ""
        avatarUrl = entity.authorAvatarUrl
    }

    init(from entity: MinimalProfileEntity) {
        uuid = entity.profileId
        nickname = entity.nickname
        avatarUrl = entity.avatarUrl
    }

    init(from profile: Com_Octopuscommunity_MinimalProfile) {
        uuid = profile.profileID
        nickname = profile.nickname
        if profile.hasAvatarURL, let profileAvatarUrl = profile.avatarURL.nilIfEmpty {
            avatarUrl = URL(string: profileAvatarUrl)
        } else {
            avatarUrl = nil
        }
    }
}

extension Optional where Wrapped == MinimalProfile {
    func isBlocked(in list: [String]) -> Bool {
        // do not block deleted user
        guard let profileId = self?.uuid else { return false }
        return list.contains(where: { $0 == profileId })
    }
}
