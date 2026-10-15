//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct PendingScrollTargetTests {

    @Test func waitsForTheLoadEvenWhenTheTargetIsAlreadyListed() {
        var target = PendingScrollTarget(id: "target")
        target.loadStarted()
        #expect(target.takeIfListed(["target"]) == nil)
    }

    @Test func isReadyOnceTheLoadSettledAndTheTargetIsListed() {
        var target = PendingScrollTarget(id: "target")
        target.loadStarted()
        target.loadSettled()
        #expect(target.takeIfListed(["other", "target"]) == "target")
    }

    @Test func waitsForTheTargetToBeListed() {
        var target = PendingScrollTarget(id: "target")
        target.loadStarted()
        target.loadSettled()
        #expect(target.takeIfListed(["other"]) == nil)
        #expect(target.takeIfListed(["other", "target"]) == "target")
    }

    @Test func isTakenOnlyOnce() {
        var target = PendingScrollTarget(id: "target")
        target.loadStarted()
        target.loadSettled()
        _ = target.takeIfListed(["target"])
        #expect(target.takeIfListed(["target"]) == nil)
    }

    @Test func noTargetNeverLoads() {
        var target = PendingScrollTarget(id: nil)
        target.loadStarted()
        #expect(!target.isLoading)
        #expect(target.takeIfListed(["any"]) == nil)
    }
}
