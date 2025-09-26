//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public struct ClientUserProfile: Sendable, Equatable {
    public let nickname: String?
    public let bio: String?
    public let picture: Data?

    static let empty: ClientUserProfile = .init(nickname: nil, bio: nil, picture: nil)

    public init(nickname: String?, bio: String?, picture: Data?) {
        self.nickname = nickname
        self.bio = bio
        self.picture = picture
    }
}

extension ClientUserProfile {
    init(from entity: ClientUserProfileEntity) {
        nickname = entity.nickname
        bio = entity.bio
        picture = entity.picture
    }
}
