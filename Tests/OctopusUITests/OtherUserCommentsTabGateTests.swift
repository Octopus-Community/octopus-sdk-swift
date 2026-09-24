//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Unit-tests for `showsOtherUserCommentsTab`, the other-member Comments tab gate. Extracted as a
/// pure function — same pattern as `canOpenHostProfile` — so the rule is testable independently of
/// the two view models that consume it (`ProfileSummaryViewModel` and `ActivityViewModel`), neither
/// of which has a SwiftUI test harness in this repo.
@Suite
struct OtherUserCommentsTabGateTests {
    @Test func flagOnWithAnAllowedFeedShowsTheTab() {
        #expect(showsOtherUserCommentsTab(showCommentsOnOtherProfiles: true, hasCommentsFeed: true,
                                          commentsForbidden: false))
    }

    @Test func flagOffNeverShowsTheTab() {
        // The ticket's core contract: the flag alone decides, on every path.
        #expect(!showsOtherUserCommentsTab(showCommentsOnOtherProfiles: false, hasCommentsFeed: true,
                                           commentsForbidden: false))
    }

    @Test func noCommentsFeedNeverShowsTheTab() {
        // Older backend, or the profile has not loaded yet: nothing to list.
        #expect(!showsOtherUserCommentsTab(showCommentsOnOtherProfiles: true, hasCommentsFeed: false,
                                           commentsForbidden: false))
    }

    @Test func serverRefusedFeedNeverShowsTheTab() {
        // The community flag can be on while this particular feed stays closed server-side.
        #expect(!showsOtherUserCommentsTab(showCommentsOnOtherProfiles: true, hasCommentsFeed: true,
                                           commentsForbidden: true))
    }

    @Test func nothingSatisfiedNeverShowsTheTab() {
        #expect(!showsOtherUserCommentsTab(showCommentsOnOtherProfiles: false, hasCommentsFeed: false,
                                           commentsForbidden: true))
    }
}
