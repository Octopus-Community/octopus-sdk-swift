//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient

public struct EditableProfile: Sendable {
    public enum FieldUpdate<T: Sendable>: Sendable {
        case unchanged
        case updated(T)

        var isUpdated: Bool {
            switch self {
            case .unchanged: return false
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

    public init(nickname: FieldUpdate<String> = .unchanged,
                bio: FieldUpdate<String?> = .unchanged,
                picture: FieldUpdate<Data?> = .unchanged,
                hasSeenOnboarding: FieldUpdate<Bool> = .unchanged,
                hasAcceptedCgu: FieldUpdate<Bool> = .unchanged,
                hasConfirmedNickname: FieldUpdate<Bool> = .unchanged,
                hasConfirmedBio: FieldUpdate<Bool> = .unchanged,
                hasConfirmedPicture: FieldUpdate<Bool> = .unchanged
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
        case .unchanged: return .notUpdated
        case .updated(let value): return .updated(value)
        }
    }

    func map<U>(_ transform: (T) throws -> U) rethrows -> EditableProfile.FieldUpdate<U> {
        switch self {
        case .unchanged: return .unchanged
        case .updated(let value): return .updated(try transform(value))
        }
    }
}
