//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
@testable import OctopusUI

/// OCT-1844: the connected-user Activity screen's tab order, and the box both tab rows share.
@Suite
struct ProfileTabsTests {
    // MARK: - Activity tab order (Notifications / Posts / Comments)

    @Test func testNotificationsIsTheFirstTab() {
        #expect(ActivityTab.notifications.viewIndex == 0)
    }

    @Test func testPostsIsTheSecondTab() {
        #expect(ActivityTab.posts.viewIndex == 1)
    }

    @Test func testLandingTabsNeverResolveToTheCommentsTab() {
        // Comments sits third and is never a landing tab, so no `ActivityTab` may map onto index 2 —
        // that is what lets Comments be inserted without disturbing either landing tab.
        let commentsTabIndex = 2
        #expect(ActivityTab.notifications.viewIndex != commentsTabIndex)
        #expect(ActivityTab.posts.viewIndex != commentsTabIndex)
    }

    @Test func testEveryLandingTabHasItsOwnIndex() {
        #expect(ActivityTab.notifications.viewIndex != ActivityTab.posts.viewIndex)
    }

    // MARK: - Shared tab box

    /// The two rows (inline underline selector and pinned pills) are two renderings of the same box.
    /// These values come from the Figma tab-bar component; pinning them here is what guards against
    /// the defect OCT-1844 fixed, where one row's geometry drifted away from the other's.
    @Test func testTabBoxMatchesTheDesignSpec() {
        #expect(ProfileTabsLayout.rowHorizontalPadding == 16)
        #expect(ProfileTabsLayout.interTabSpacing == 8)
        #expect(ProfileTabsLayout.tabHorizontalPadding == 16)
        #expect(ProfileTabsLayout.tabVerticalPadding == 10)
    }

    // MARK: - Underline placement

    @Test func testUnderlineIsNotOffsetWhenTheTabIsAlreadyOnTheRowCentre() {
        #expect(ProfileTabsLayout.underlineOffset(tabMidX: 200, rowWidth: 400,
                                                  layoutDirection: .leftToRight) == 0)
        #expect(ProfileTabsLayout.underlineOffset(tabMidX: 200, rowWidth: 400,
                                                  layoutDirection: .rightToLeft) == 0)
    }

    @Test func testUnderlineFollowsThePhysicalDeltaInLeftToRight() {
        // A tab whose centre sits 100pt right of the row's centre needs a +100 offset.
        #expect(ProfileTabsLayout.underlineOffset(tabMidX: 300, rowWidth: 400,
                                                  layoutDirection: .leftToRight) == 100)
        #expect(ProfileTabsLayout.underlineOffset(tabMidX: 100, rowWidth: 400,
                                                  layoutDirection: .leftToRight) == -100)
    }

    @Test func testUnderlineNegatesThePhysicalDeltaInRightToLeft() {
        // `offset(x:)` is mirrored in RTL while `frame(in:)` is not, so the same physically-right tab
        // needs the opposite offset — without this the underline lands on the symmetric tab.
        #expect(ProfileTabsLayout.underlineOffset(tabMidX: 300, rowWidth: 400,
                                                  layoutDirection: .rightToLeft) == -100)
        #expect(ProfileTabsLayout.underlineOffset(tabMidX: 100, rowWidth: 400,
                                                  layoutDirection: .rightToLeft) == 100)
    }
}
