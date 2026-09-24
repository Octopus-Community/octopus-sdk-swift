//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A read-only snapshot of a member's public Octopus community activity (Unified Profile).
///
/// A dedicated, additive type so a host app can surface community stats (message count, gamification
/// level) inside its **own** profile screen, consuming them à la carte — without rendering any
/// Octopus UI. Fetch a one-off snapshot with ``OctopusSDK/fetchCommunityData(clientUserId:)`` or
/// observe it reactively with ``OctopusSDK/communityDataPublisher(clientUserId:)``.
///
/// Future fields will be added here — additive only; no breaking changes.
public struct OctopusCommunityData: Sendable {
    /// The member's Octopus profile id.
    public let profileId: String

    /// The number of messages (posts + comments + replies) the member has published, or `nil` when
    /// the community does not surface it.
    public let messageCount: Int?

    /// The member's gamification standing, or `nil` when the community has gamification disabled (the
    /// profile then carries no level).
    public let gamification: OctopusGamification?

    /// Maps a Core public profile to its community-data snapshot.
    ///
    /// - Note: an other-member profile carries no per-user gamification score (only the level), so
    ///   ``OctopusGamification/score`` is always `nil` here.
    init(from profile: Profile) {
        self.profileId = profile.id
        self.messageCount = profile.totalMessages
        self.gamification = profile.gamificationLevel.map {
            OctopusGamification(level: $0.level, score: nil)
        }
    }
}

/// A member's read-only gamification standing (Unified Profile).
public struct OctopusGamification: Sendable {
    /// The member's gamification level (0-based index).
    public let level: Int

    /// The member's gamification score, or `nil` when unavailable.
    ///
    /// - Note: always `nil` for other members — the SDK does not expose a per-user score on the
    ///   public profile. Kept in the API for forward-compatibility.
    public let score: Int?
}
