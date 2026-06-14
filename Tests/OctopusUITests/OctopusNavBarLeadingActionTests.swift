//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

/// Tests for the pure `onTap` accessor of `OctopusNavBarLeadingAction`, used by the root screens to wire
/// the host-provided callback onto the leading nav-bar button (regardless of close vs back).
struct OctopusNavBarLeadingActionTests {

    @Test func closeForwardsItsClosure() {
        var tapped = false
        OctopusNavBarLeadingAction.close(onTap: { tapped = true }).onTap()
        #expect(tapped == true)
    }

    @Test func backForwardsItsClosure() {
        var tapped = false
        OctopusNavBarLeadingAction.back(onTap: { tapped = true }).onTap()
        #expect(tapped == true)
    }
}
