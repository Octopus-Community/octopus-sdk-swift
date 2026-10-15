//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct PendingPollVoteTests {

    @Test func showsNoPickBeforeAnyTap() {
        let pending = PendingPollVote()
        #expect(pending.optionId == nil)
    }

    @Test func showsTheTappedOptionAsPickedWhileTheVoteIsInFlight() {
        var pending = PendingPollVote()
        pending.start(optionId: "option")
        #expect(pending.optionId == "option")
    }

    @Test func givesTheOptionsBackWhenTheVoteWasNotCast() {
        var pending = PendingPollVote()
        pending.start(optionId: "option")
        pending.settle(voted: false)
        #expect(pending.optionId == nil)
    }

    @Test func keepsThePickWhenTheVoteWasCastUntilThePostCarriesIt() {
        var pending = PendingPollVote()
        pending.start(optionId: "option")
        pending.settle(voted: true)
        #expect(pending.optionId == "option")
    }

    @Test func dropsThePickOnceThePostCarriesTheVote() {
        var pending = PendingPollVote()
        pending.start(optionId: "option")
        pending.settle(voted: true)
        pending.confirmed()
        #expect(pending.optionId == nil)
    }
}
