//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient

public struct EditableProfile: Sendable {
    public enum FieldUpdate<T: Sendable>: Sendable {
        case notUpdated
        case updated(T)

        var isUpdated: Bool {
            switch self {
            case .notUpdated: return false
            case .updated: return true
            }
        }
    }

    public let nickname: FieldUpdate<String>
    public let bio: FieldUpdate<String?>
    public internal(set) var picture: FieldUpdate<Data?>

    public let hasSeenOnboarding: FieldUpdate<Bool>
    public let hasAcceptedCgu: FieldUpdate<Bool>
    public let hasConfirmedNickname: FieldUpdate<Bool>
    public let hasConfirmedBio: FieldUpdate<Bool>
    public let hasConfirmedPicture: FieldUpdate<Bool>

    public init(nickname: FieldUpdate<String> = .notUpdated,
                bio: FieldUpdate<String?> = .notUpdated,
                picture: FieldUpdate<Data?> = .notUpdated,
                hasSeenOnboarding: FieldUpdate<Bool> = .notUpdated,
                hasAcceptedCgu: FieldUpdate<Bool> = .notUpdated,
                hasConfirmedNickname: FieldUpdate<Bool> = .notUpdated,
                hasConfirmedBio: FieldUpdate<Bool> = .notUpdated,
                hasConfirmedPicture: FieldUpdate<Bool> = .notUpdated
    ) {
        self.nickname = nickname
        self.bio = bio
        self.picture = picture
        self.hasSeenOnboarding = hasSeenOnboarding
        self.hasAcceptedCgu = hasAcceptedCgu
        self.hasConfirmedNickname = hasConfirmedNickname
        self.hasConfirmedBio = hasConfirmedBio
        self.hasConfirmedPicture = hasConfirmedPicture
    }
}

/// Extension that adds translation to OctopusRemoteClient.FieldUpdate
extension EditableProfile.FieldUpdate {
    var backendValue: UpdateProfileData.FieldUpdate<T> {
        switch self {
        case .notUpdated: return .notUpdated
        case .updated(let value): return .updated(value)
        }
    }

    func map<U>(_ transform: (T) throws -> U) rethrows -> EditableProfile.FieldUpdate<U> {
        switch self {
        case .notUpdated: return .notUpdated
        case .updated(let value): return .updated(try transform(value))
        }
    }
}
