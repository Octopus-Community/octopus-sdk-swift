//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Unit-tests for the Unified Profile routing (OCT-1374, ported from Android's ProfileTapTargetTest):
/// - `unifiedProfileActive`: the activation gate — active iff the community exposes client user ids
///   (backend) AND the host wired `onNavigateToProfileCallback`.
/// - `resolveProfileTapTarget`: once activation is known, a member with a client id opens the host
///   profile, one without (guest / BO / admin) opens the Octopus activity, and an inactive feature
///   keeps the native profile.
@Suite
struct ProfileTapRoutingTests {
    // MARK: - unifiedProfileActive: the AND gate

    @Test func activeOnlyWhenFlagOnAndCallbackWired() {
        #expect(unifiedProfileActive(exposeClientUserId: true, onNavigateToProfileWired: true))
    }

    @Test func flagOnButCallbackUnwiredIsInactive() {
        #expect(!unifiedProfileActive(exposeClientUserId: true, onNavigateToProfileWired: false))
    }

    @Test func callbackWiredButFlagOffIsInactive() {
        #expect(!unifiedProfileActive(exposeClientUserId: false, onNavigateToProfileWired: true))
    }

    @Test func neitherSignalIsInactive() {
        #expect(!unifiedProfileActive(exposeClientUserId: false, onNavigateToProfileWired: false))
    }

    // MARK: - resolveProfileTapTarget: routing once activation is known

    @Test func inactiveFeatureOpensNativeProfileEvenWithAClientId() {
        #expect(resolveProfileTapTarget(unifiedActive: false, clientUserId: "client-1") == .nativeProfile)
    }

    @Test func inactiveFeatureOpensNativeProfileWithNoClientId() {
        #expect(resolveProfileTapTarget(unifiedActive: false, clientUserId: nil) == .nativeProfile)
    }

    @Test func activeFeatureWithAClientIdOpensTheHostProfile() {
        #expect(resolveProfileTapTarget(unifiedActive: true, clientUserId: "client-1") == .hostClientProfile)
    }

    @Test func activeFeatureWithoutAClientIdOpensTheOctopusActivity() {
        // Guards the "never hand the host a nil id" contract: BO / guest / admin → Octopus activity.
        #expect(resolveProfileTapTarget(unifiedActive: true, clientUserId: nil) == .octopusActivity)
    }
}
