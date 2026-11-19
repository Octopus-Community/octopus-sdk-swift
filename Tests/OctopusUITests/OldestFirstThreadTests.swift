//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct OldestFirstThreadTests {

    @Test func listsNothingBeforeTheFirstPage() {
        #expect(OldestFirstThread.listed(oldestFirst: nil, reachedEnd: false,
                                         newestFirst: ["1000", "999"], id: { $0 }) == nil)
    }

    @Test func listsNothingWhileNoStoredResponseStartsTheThread() {
        #expect(OldestFirstThread.listed(oldestFirst: [], reachedEnd: false,
                                         newestFirst: ["1000", "999"], id: { $0 }) == nil)
    }

    @Test func listsOnlyTheLoadedPagesBeforeTheEndOfTheThread() {
        #expect(OldestFirstThread.listed(oldestFirst: ["1", "2"], reachedEnd: false,
                                         newestFirst: ["1000", "999"], id: { $0 }) == ["1", "2"])
    }

    @Test func addsTheNewestResponsesNotListedYetOnceTheEndIsReached() {
        #expect(OldestFirstThread.listed(oldestFirst: ["1", "2"], reachedEnd: true,
                                         newestFirst: ["4", "3", "2"], id: { $0 }) == ["1", "2", "3", "4"])
    }

    @Test func listsAThreadKnownEmptyAsEmpty() {
        #expect(OldestFirstThread.listed(oldestFirst: [], reachedEnd: true,
                                         newestFirst: [String](), id: { $0 }) == [])
    }

    @Test func listsTheNewestResponsesOfAThreadKnownEmpty() {
        #expect(OldestFirstThread.listed(oldestFirst: [], reachedEnd: true,
                                         newestFirst: ["2", "1"], id: { $0 }) == ["1", "2"])
    }
}
