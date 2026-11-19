//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

@Suite
@MainActor
struct CreatePostImagesStripTests {
    @Test(arguments: [(3, 5), (1, 2), (4, 5)])
    func scrollsWhenPhotosAreAdded(_ counts: (previous: Int, new: Int)) {
        #expect(CreatePostImagesStrip.shouldScrollToLast(from: counts.previous, to: counts.new))
    }

    @Test(arguments: [(5, 4), (3, 1), (1, 0)])
    func doesNotScrollWhenPhotosAreRemoved(_ counts: (previous: Int, new: Int)) {
        #expect(!CreatePostImagesStrip.shouldScrollToLast(from: counts.previous, to: counts.new))
    }

    @Test func doesNotScrollWhenTheCountIsUnchanged() {
        #expect(!CreatePostImagesStrip.shouldScrollToLast(from: 3, to: 3))
    }
}
