//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A read-only snapshot of a member's public Octopus community activity (Unified Profile).
///
/// A dedicated, additive type so a host app can surface community stats (message count, gamification
/// level and total points) inside its **own** profile screen, consuming them à la carte — without rendering any
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
    /// profile then carries no level) or the profile is tagged admin.
    public let gamification: OctopusGamification?

    /// Maps a Core public profile to its community-data snapshot.
    ///
    /// The total points come from the cached public profile only: the Octopus screens never show them for
    /// another member. A profile tagged admin has no gamification standing, even if a level is cached for it.
    init(from profile: Profile) {
        self.profileId = profile.id
        self.messageCount = profile.totalMessages
        if profile.tags.contains(.admin) {
            self.gamification = nil
        } else {
            self.gamification = profile.gamificationLevel.map {
                OctopusGamification(level: $0.level, score: profile.gamificationScore)
            }
        }
    }
}

/// A member's read-only gamification standing (Unified Profile).
///
/// Present only when gamification is enabled for the community and the profile is not tagged admin (see
/// ``OctopusCommunityData/gamification``).
public struct OctopusGamification: Sendable {
    /// The member's gamification level (0-based index).
    public let level: Int

    /// The member's total gamification points, for the connected member as for any other member, or `nil`
    /// when the total is not known.
    ///
    /// It is read again on every refresh, so it includes the points earned since the last one, including
    /// the points your app awarded. It is `nil` for a profile cached before the SDK read the total, until
    /// that profile is fetched again, and when the server does not send it. The Octopus screens keep
    /// showing only the connected member's own points.
    public let score: Int?
}
