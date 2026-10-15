//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// Why a contribution that `ensureConnected` held back waits to be sent again.
enum PendingSendReason: Equatable {
    /// The nickname choice screen is open for this member: the contribution goes once they confirm their nickname,
    /// and only then, so a profile update while the member types does not send it early. It belongs to that member:
    /// it never goes out under another one.
    case nicknameChoice(profileId: String)
    /// Any other block: a login, a config load, a connection retry or a ban.
    case connection

    /// The facts of the connected profile that decide whether a held contribution goes.
    struct Profile: Equatable {
        let id: String
        let isGuest: Bool
        let hasConfirmedNickname: Bool
    }

    /// What a profile update does to the held contribution.
    enum Resolution: Equatable {
        /// It stays held.
        case keepWaiting
        /// It is sent now.
        case send
        /// It is forgotten without being sent. The draft stays in the composer.
        case drop
    }

    /// Why a contribution that `ensureConnected` just blocked is held.
    /// - Parameters:
    ///   - isBlockedOnlyByNicknameChoice: whether the nickname choice screen is the only thing in the way.
    ///   - profileId: the connected profile, which the nickname choice is made for.
    static func held(isBlockedOnlyByNicknameChoice: Bool, profileId: String?) -> PendingSendReason {
        guard isBlockedOnlyByNicknameChoice, let profileId else { return .connection }
        return .nicknameChoice(profileId: profileId)
    }

    /// What a profile update does to the held contribution.
    ///
    /// A login can go through a moment without any profile (from the guest to the signed-in member), so a
    /// contribution waiting for a login keeps waiting then. A contribution waiting for a nickname choice is
    /// dropped as soon as its member is gone: the screen closed, and it must not go out under the next member.
    func resolution(for profile: Profile?) -> Resolution {
        switch self {
        case .connection:
            guard let profile else { return .keepWaiting }
            return !profile.isGuest || profile.hasConfirmedNickname ? .send : .keepWaiting
        case let .nicknameChoice(profileId):
            guard let profile, profile.id == profileId else { return .drop }
            return profile.hasConfirmedNickname ? .send : .keepWaiting
        }
    }

    /// Whether a freshly loaded community config lets the contribution be tried again.
    var resumesOnConfigChange: Bool { self == .connection }
}

extension PendingSendReason.Profile {
    init(_ profile: CurrentUserProfile) {
        self.init(id: profile.id, isGuest: profile.isGuest, hasConfirmedNickname: profile.hasConfirmedNickname)
    }
}
