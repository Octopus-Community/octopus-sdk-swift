//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Unit-tests for `contentAreaState`, the rule every list in the SDK follows to decide between its
/// content, the state that stands in for it, and the loader.
///
/// Each test here locks a defect that reached TestFlight while the screens each had their own ladder
/// of `if`s: the empty state shown while the first load was still running, the empty state flashing
/// between a failure and its retry, and the loader that never gave way once a load path forgot to
/// report its outcome.
@Suite
struct ContentAreaStateTests {
    @Test func nothingLoadedYetShowsTheLoader() {
        // The local store populates the list before the server answers, so both shapes of "nothing
        // yet" — no list at all, or an empty one — have to hold the loader.
        #expect(contentAreaState(itemCount: nil, hasLoadedOnce: false, loadFailure: nil) == .loader)
        #expect(contentAreaState(itemCount: 0, hasLoadedOnce: false, loadFailure: nil) == .loader)
    }

    @Test func anEmptyListIsOnlyEmptyOnceTheFirstLoadSettled() {
        #expect(contentAreaState(itemCount: 0, hasLoadedOnce: true, loadFailure: nil) == .empty)
    }

    @Test func contentWins() {
        #expect(contentAreaState(itemCount: 3, hasLoadedOnce: true, loadFailure: nil) == .content)
        // Content from the local store shows immediately, without waiting for the server.
        #expect(contentAreaState(itemCount: 3, hasLoadedOnce: false, loadFailure: nil) == .content)
    }

    @Test func aFailureReplacesTheEmptyState() {
        // Both describe an area with nothing in it; only the failure says why and offers a way out.
        #expect(contentAreaState(itemCount: 0, hasLoadedOnce: true, loadFailure: .noNetwork)
                == .failure(.noNetwork))
        #expect(contentAreaState(itemCount: nil, hasLoadedOnce: true, loadFailure: .other)
                == .failure(.other))
    }

    /// The retry sequence: clearing the failure alone dropped the screen through to the empty state
    /// until the new attempt settled — offline that round trip is immediate, so it read as a flicker.
    @Test func retryingGoesThroughTheLoaderAndNeverTheEmptyState() {
        let onFailure = contentAreaState(itemCount: 0, hasLoadedOnce: true, loadFailure: .noNetwork)
        #expect(onFailure == .failure(.noNetwork))

        // What a retry does: drop the failure and un-settle the first load.
        let whileRetrying = contentAreaState(itemCount: 0, hasLoadedOnce: false, loadFailure: nil)
        #expect(whileRetrying == .loader)

        let failedAgain = contentAreaState(itemCount: 0, hasLoadedOnce: true, loadFailure: .noNetwork)
        #expect(failedAgain == .failure(.noNetwork))
    }

    /// A load path that forgets to settle the first load leaves the loader up forever. The rule
    /// cannot prevent that on its own — this pins the contract the view models have to honour.
    @Test func theLoaderOnlyEndsWhenTheFirstLoadSettles() {
        #expect(contentAreaState(itemCount: 0, hasLoadedOnce: false, loadFailure: nil) == .loader)
        #expect(contentAreaState(itemCount: 0, hasLoadedOnce: true, loadFailure: nil) != .loader)
    }
}
