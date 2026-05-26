//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// The public-facing profile of the connected user.
///
/// Exposed via ``OctopusSDK/profile``. Future profile fields will be added to this struct —
/// additive only; no breaking changes.
public struct OctopusProfile: Sendable {
    /// Held entitlement identifiers (opaque tokens defined by the host app).
    ///
    /// Display only — the SDK never intersects this set against per-group requirements.
    /// Group access decisions are pre-resolved by the backend and surfaced via
    /// ``OctopusGroup/canAccess``.
    public let entitlements: Set<String>

    init(from profile: OctopusCore.CurrentUserProfile) {
        self.entitlements = profile.entitlements
    }
}
