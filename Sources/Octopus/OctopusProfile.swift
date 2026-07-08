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

    /// Whether this profile belongs to an anonymous guest rather than a real, authenticated user.
    ///
    /// In forced-login communities a guest session is re-established right after
    /// ``OctopusSDK/disconnectUser()``, so ``OctopusSDK/profile`` becomes non-nil again without the
    /// user having authenticated. Check this flag to gate real-user features and to tell a guest
    /// apart from an authenticated user. Mirrors Android's `ConnectionState.Connected.isGuest`.
    public let isGuest: Bool

    init(from profile: OctopusCore.CurrentUserProfile) {
        self.entitlements = profile.entitlements
        self.isGuest = profile.isGuest
    }
}
