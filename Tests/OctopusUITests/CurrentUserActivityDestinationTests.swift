//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Unit-tests for `currentUserActivityDestination`, the home floating-button routing that backs
/// Unified Profile (OCT-1374, ported from Android's `CurrentUserActivityDestinationTest`). When
/// Unified Profile is active (the community exposes client user ids AND the host wired
/// `onNavigateToProfile`) the button opens the standalone Activity screen — always on the
/// Notifications tab, because the button shows a bell (PO feedback, 2026-07-17); otherwise it keeps
/// opening the legacy profile summary, whose tab follows the unseen-notifications rule.
@Suite
struct CurrentUserActivityDestinationTests {
    @Test func featureOffNoUnseenOpensTheProfileSummaryOnPosts() {
        #expect(
            currentUserActivityDestination(unifiedProfileEnabled: false, hasUnseenNotifications: false)
                == .currentUserProfilePosts)
    }

    @Test func featureOffUnseenOpensTheProfileSummaryOnNotifications() {
        #expect(
            currentUserActivityDestination(unifiedProfileEnabled: false, hasUnseenNotifications: true)
                == .currentUserProfileNotifications)
    }

    @Test func featureOnNoUnseenStillOpensTheActivityScreenOnNotifications() {
        #expect(
            currentUserActivityDestination(unifiedProfileEnabled: true, hasUnseenNotifications: false)
                == .activityNotifications)
    }

    @Test func featureOnUnseenOpensTheActivityScreenOnNotifications() {
        #expect(
            currentUserActivityDestination(unifiedProfileEnabled: true, hasUnseenNotifications: true)
                == .activityNotifications)
    }
}
