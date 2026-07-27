//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

/// Unit-tests for the additive `otherUserPosts` screen-displayed context (Unified Profile, OCT-1374),
/// iOS's counterpart of Android's `ScreenDisplayed.OtherUserPosts`. Locks the new case + its context
/// struct so the additive Core change can't regress.
@Suite
struct ScreenDisplayedContextTests {
    @Test func otherUserPostsContextCarriesProfileId() {
        let context = SdkEvent.ScreenDisplayedContext.OtherUserPostsContext(profileId: "profile-42")
        #expect(context.profileId == "profile-42")
    }

    @Test func otherUserPostsCaseWrapsItsContext() {
        let screen = SdkEvent.ScreenDisplayedContext.otherUserPosts(.init(profileId: "profile-42"))
        guard case let .otherUserPosts(context) = screen else {
            Issue.record("Expected .otherUserPosts, got \(screen)")
            return
        }
        #expect(context.profileId == "profile-42")
    }
}
