//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Unit-tests for `canOpenHostProfile`, the connected-user Activity screen's overflow-menu gate
/// (OCT-1374): whether "View my profile" / "Edit my profile" can be shown. Extracted as a pure
/// function (same pattern as `unifiedProfileActive`) so the "as-wired" gating — otherwise buried in
/// `ActivityView.trailingBarItem`, which has no SwiftUI test harness in this repo (no ViewInspector) —
/// stays independently unit-testable.
@Suite
struct CanOpenHostProfileTests {
    @Test func nominalCaseAllConditionsMetOpensTheHostProfile() {
        #expect(canOpenHostProfile(exposeClientUserId: true, onNavigateToProfileWired: true,
                                   isGuest: false, connectedUserClientUserId: "client-1"))
    }

    @Test func guestNeverOpensTheHostProfileEvenWithAClientId() {
        // Defensive: a guest should never carry a client user id, but the gate must hold regardless.
        #expect(!canOpenHostProfile(exposeClientUserId: true, onNavigateToProfileWired: true,
                                    isGuest: true, connectedUserClientUserId: "client-1"))
    }

    @Test func noClientUserIdNeverOpensTheHostProfile() {
        // BO / admin-created profiles have no client id even when the feature is active.
        #expect(!canOpenHostProfile(exposeClientUserId: true, onNavigateToProfileWired: true,
                                    isGuest: false, connectedUserClientUserId: nil))
    }

    @Test func backendFlagOffNeverOpensTheHostProfile() {
        #expect(!canOpenHostProfile(exposeClientUserId: false, onNavigateToProfileWired: true,
                                    isGuest: false, connectedUserClientUserId: "client-1"))
    }

    @Test func callbackUnwiredNeverOpensTheHostProfile() {
        #expect(!canOpenHostProfile(exposeClientUserId: true, onNavigateToProfileWired: false,
                                    isGuest: false, connectedUserClientUserId: "client-1"))
    }

    @Test func neitherSignalNorProfileNeverOpensTheHostProfile() {
        #expect(!canOpenHostProfile(exposeClientUserId: false, onNavigateToProfileWired: false,
                                    isGuest: true, connectedUserClientUserId: nil))
    }
}
