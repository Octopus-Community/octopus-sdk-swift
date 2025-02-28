//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public struct ClientUserProfile: Sendable, Equatable {
    public enum AgeInformation: Sendable {
        case legalAgeReached
        case underaged
    }

    public let nickname: String?
    public let bio: String?
    public let picture: Data?
    public let ageInformation: AgeInformation?

    static let empty: ClientUserProfile = .init(nickname: nil, bio: nil, picture: nil, ageInformation: nil)

    public init(nickname: String?, bio: String?, picture: Data?, ageInformation: AgeInformation?) {
        self.nickname = nickname
        self.bio = bio
        self.picture = picture
        self.ageInformation = ageInformation
    }
}

extension ClientUserProfile {
    init(from entity: ClientUserProfileEntity) {
        nickname = entity.nickname
        bio = entity.bio
        picture = entity.picture
        ageInformation = .init(from: entity.ageInformation)
    }
}

extension ClientUserProfile.AgeInformation {
    init?(from entity: ClientUserProfileEntity.AgeInformation) {
        switch entity {
        case .legalAgeReached: self = .legalAgeReached
        case .underaged: self = .underaged
        case .unknown: return nil
        }
    }
}

extension Optional where Wrapped == ClientUserProfile.AgeInformation {
    var entity: ClientUserProfileEntity.AgeInformation {
        return switch self {
        case .legalAgeReached:  .legalAgeReached
        case .underaged:        .underaged
        case .none:             .unknown
        }
    }
}
