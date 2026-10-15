//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Height of a content-sized sheet: its content's height up to 80 % of the window, scrolling beyond.
struct ContentSizedSheetLayoutTests {

    @Test func shortContentIsNotCapped() {
        #expect(ContentSizedSheetLayout.height(contentHeight: 300, windowHeight: 800, fallbackWindowHeight: 0) == 300)
        #expect(!ContentSizedSheetLayout.scrolls(contentHeight: 300, windowHeight: 800, fallbackWindowHeight: 0))
    }

    @Test func contentOfExactlyTheCapDoesNotScroll() {
        #expect(ContentSizedSheetLayout.height(contentHeight: 640, windowHeight: 800, fallbackWindowHeight: 0) == 640)
        #expect(!ContentSizedSheetLayout.scrolls(contentHeight: 640, windowHeight: 800, fallbackWindowHeight: 0))
    }

    @Test func longContentIsCappedAndScrolls() {
        // 800 × 0.8 = 640.
        #expect(ContentSizedSheetLayout.height(contentHeight: 2_000, windowHeight: 800, fallbackWindowHeight: 0)
                == 640)
        #expect(ContentSizedSheetLayout.scrolls(contentHeight: 2_000, windowHeight: 800, fallbackWindowHeight: 0))
    }

    @Test func aWindowShorterThanTheScreenLowersTheCap() {
        // A Stage Manager window of 600 pt on a 1000 pt screen: 600 × 0.8 = 480, not 800.
        #expect(ContentSizedSheetLayout.height(contentHeight: 2_000, windowHeight: 600, fallbackWindowHeight: 1_000)
                == 480)
        #expect(ContentSizedSheetLayout.scrolls(contentHeight: 500, windowHeight: 600, fallbackWindowHeight: 1_000))
    }

    @Test func aWindowTallerThanTheMainScreenRaisesTheCap() {
        // A 1200 pt window on an external display, the main screen being 800 pt: 1200 × 0.8 = 960, not 640.
        #expect(ContentSizedSheetLayout.height(contentHeight: 2_000, windowHeight: 1_200, fallbackWindowHeight: 800)
                == 960)
        #expect(!ContentSizedSheetLayout.scrolls(contentHeight: 900, windowHeight: 1_200, fallbackWindowHeight: 800))
    }

    @Test func theFallbackStandsInWhileTheWindowHeightIsUnknown() {
        // Never uncapped on the first pass: 800 × 0.8 = 640 from the fallback height.
        #expect(ContentSizedSheetLayout.height(contentHeight: 2_000, windowHeight: 0, fallbackWindowHeight: 800)
                == 640)
        #expect(ContentSizedSheetLayout.scrolls(contentHeight: 2_000, windowHeight: 0, fallbackWindowHeight: 800))
        #expect(!ContentSizedSheetLayout.scrolls(contentHeight: 300, windowHeight: 0, fallbackWindowHeight: 800))
    }

    @Test func noHeightKnownMeansNoCapRatherThanAZeroCap() {
        #expect(ContentSizedSheetLayout.height(contentHeight: 2_000, windowHeight: 0, fallbackWindowHeight: 0)
                == 2_000)
        #expect(!ContentSizedSheetLayout.scrolls(contentHeight: 2_000, windowHeight: 0, fallbackWindowHeight: 0))
    }
}
