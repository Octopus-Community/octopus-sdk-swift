//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

/// What the group screen does when the topics it receives do not list its group. The logout purge empties the
/// groups, so a group on screen is confirmed with the server before the screen shows it as gone.
struct GroupDetailMissingGroupTests {
    @Test func aGroupOnScreenIsConfirmedWithTheServer() {
        #expect(resolve(isShowingGroup: true, hasFetchedTopicsOnce: true) == .confirm)
        #expect(resolve(isShowingGroup: true, hasFetchedTopicsOnce: false) == .confirm)
    }

    @Test func aRunningConfirmationIsNotStartedAgain() {
        #expect(resolve(isConfirming: true, isShowingGroup: true, hasFetchedTopicsOnce: true) == .wait)
        #expect(resolve(isConfirming: true, isShowingGroup: false, hasFetchedTopicsOnce: true) == .wait)
    }

    @Test func aGroupNeverShownAndNotFetchedIsNotFound() {
        #expect(resolve(isShowingGroup: false, hasFetchedTopicsOnce: true) == .notFound)
    }

    @Test func aGroupNeverShownWaitsForTheFirstFetch() {
        #expect(resolve(isShowingGroup: false, hasFetchedTopicsOnce: false) == .wait)
    }

    private func resolve(isConfirming: Bool = false, isShowingGroup: Bool,
                         hasFetchedTopicsOnce: Bool) -> MissingGroupResolution {
        MissingGroupResolution(isConfirming: isConfirming, isShowingGroup: isShowingGroup,
                               hasFetchedTopicsOnce: hasFetchedTopicsOnce)
    }
}
