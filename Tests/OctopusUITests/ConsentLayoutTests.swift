//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Heights of the consent sheet's scroll area: content height up to a cap, scrolling beyond.
/// Main-actor bound: the helpers are statics of SwiftUI views.
@MainActor
struct ConsentLayoutTests {

    // MARK: Consent sheet

    @Test func sheetScrollAreaFollowsShortContent() {
        #expect(TermsConsentSheet.scrollAreaHeight(contentHeight: 200, buttonAreaHeight: 100,
                                                   windowHeight: 800, fallbackWindowHeight: 0)
                == 200)
    }

    @Test func sheetScrollAreaIsCappedForLongContent() {
        // 800 × 0.8 − 100 = 540: the scroll area and the pinned button stay within 80 % of the window.
        #expect(TermsConsentSheet.scrollAreaHeight(contentHeight: 2_000, buttonAreaHeight: 100,
                                                   windowHeight: 800, fallbackWindowHeight: 0)
                == 540)
    }

    @Test func sheetScrollAreaIsNeverNegative() {
        #expect(TermsConsentSheet.scrollAreaHeight(contentHeight: 300, buttonAreaHeight: 900,
                                                   windowHeight: 800, fallbackWindowHeight: 0)
                == 0)
    }

    @Test func sheetScrollAreaUsesTheFallbackWhileTheWindowHeightIsUnknown() {
        // Never unbounded on the first pass: 800 × 0.8 − 100 = 540 from the fallback height.
        #expect(TermsConsentSheet.scrollAreaHeight(contentHeight: 2_000, buttonAreaHeight: 100, windowHeight: 0,
                                                   fallbackWindowHeight: 800) == 540)
        #expect(TermsConsentSheet.scrollAreaHeight(contentHeight: 200, buttonAreaHeight: 100, windowHeight: 0,
                                                   fallbackWindowHeight: 800) == 200)
    }

    @Test func sheetScrollAreaIgnoresTheFallbackOnceTheWindowHeightIsKnown() {
        // A Stage Manager window of 600 pt on a 1000 pt screen: 600 × 0.8 − 100 = 380, not 700.
        #expect(TermsConsentSheet.scrollAreaHeight(contentHeight: 2_000, buttonAreaHeight: 100, windowHeight: 600,
                                                   fallbackWindowHeight: 1_000) == 380)
    }

    @Test func sheetScrollAreaHasNoCapWhenNeitherHeightIsKnown() {
        #expect(TermsConsentSheet.scrollAreaHeight(contentHeight: 2_000, buttonAreaHeight: 100, windowHeight: 0,
                                                   fallbackWindowHeight: 0) == 2_000)
    }

    // MARK: Implicit consent notice

    @Test func noticeShowsAFullFiveLinesWithoutScrolling() {
        // The content and the cap are measured on two different views: a sub-point difference between a text of
        // exactly five lines and the cap must not make the notice scroll.
        #expect(!ImplicitConsentNotice.scrolls(contentHeight: 70.4, maxHeight: 70,
                                               windowHeight: 800, fallbackWindowHeight: 0))
    }

    @Test func noticeScrollsOnlyBeyondItsCap() {
        #expect(!ImplicitConsentNotice.scrolls(contentHeight: 30, maxHeight: 70,
                                               windowHeight: 800, fallbackWindowHeight: 0))
        #expect(ImplicitConsentNotice.scrolls(contentHeight: 300, maxHeight: 70,
                                              windowHeight: 800, fallbackWindowHeight: 0))
        // Cap not measured yet: nothing to scroll.
        #expect(!ImplicitConsentNotice.scrolls(contentHeight: 300, maxHeight: 0,
                                               windowHeight: 800, fallbackWindowHeight: 0))
    }

    @Test func noticeShowsHalfALineMoreWhenItScrolls() {
        // 5 lines of 14 pt = 70; the scrolling notice shows 5.5 lines = 77, so the cut-off line hints at more.
        // 77 is below 20 % of an 800 pt window (160): the line cap decides.
        #expect(ImplicitConsentNotice.scrollingHeight(maxHeight: 70, windowHeight: 800, fallbackWindowHeight: 0) == 77)
    }

    @Test func noticeRelativeCapWinsAtAHugeLineHeight() {
        // Largest accessibility size: 5 lines of 60 pt = 300, 5.5 lines = 330. 20 % of 800 = 160 wins.
        #expect(ImplicitConsentNotice.scrollingHeight(maxHeight: 300,
                                                      windowHeight: 800, fallbackWindowHeight: 0) == 160)
        // Content of 200 fits the 5 lines (300) but not the relative cap: it scrolls.
        #expect(ImplicitConsentNotice.scrolls(contentHeight: 200, maxHeight: 300,
                                              windowHeight: 800, fallbackWindowHeight: 0))
    }

    @Test func noticeLineCapWinsAtNormalSizes() {
        // 5.5 lines of 14 pt = 77 < 20 % of 800: the notice is unchanged at common text sizes.
        #expect(ImplicitConsentNotice.scrollingHeight(maxHeight: 70, windowHeight: 800, fallbackWindowHeight: 0) == 77)
        #expect(!ImplicitConsentNotice.scrolls(contentHeight: 70, maxHeight: 70,
                                               windowHeight: 800, fallbackWindowHeight: 0))
    }

    @Test func noticeBetweenTheRelativeCapAndFiveLinesScrolls() {
        // 5 lines of 40 pt = 200; 20 % of 800 = 160. A 4-line notice (160) fits both, 5 lines (200) only the line cap.
        #expect(!ImplicitConsentNotice.scrolls(contentHeight: 160.5, maxHeight: 200,
                                               windowHeight: 800, fallbackWindowHeight: 0))
        #expect(ImplicitConsentNotice.scrolls(contentHeight: 180, maxHeight: 200,
                                              windowHeight: 800, fallbackWindowHeight: 0))
        #expect(ImplicitConsentNotice.scrollingHeight(maxHeight: 200,
                                                      windowHeight: 800, fallbackWindowHeight: 0) == 160)
    }

    @Test func noticeUsesTheFallbackRelativeCapWhileTheWindowIsUnknown() {
        // Unknown window, 800 pt fallback: the relative cap (160) applies from the first pass.
        #expect(ImplicitConsentNotice.scrollingHeight(maxHeight: 300, windowHeight: 0, fallbackWindowHeight: 800)
                == 160)
        #expect(ImplicitConsentNotice.scrolls(contentHeight: 200, maxHeight: 300, windowHeight: 0,
                                              fallbackWindowHeight: 800))
        #expect(!ImplicitConsentNotice.scrolls(contentHeight: 50, maxHeight: 70, windowHeight: 0,
                                               fallbackWindowHeight: 800))
    }

    @Test func noticeIgnoresTheFallbackOnceTheWindowHeightIsKnown() {
        // A window of 400 pt on a 1000 pt screen: 20 % of 400 = 80, not 200.
        #expect(ImplicitConsentNotice.scrollingHeight(maxHeight: 300, windowHeight: 400, fallbackWindowHeight: 1_000)
                == 80)
    }

    @Test func noticeHasOnlyTheLineCapWhenNeitherHeightIsKnown() {
        #expect(ImplicitConsentNotice.scrollingHeight(maxHeight: 70, windowHeight: 0, fallbackWindowHeight: 0) == 77)
        #expect(!ImplicitConsentNotice.scrolls(contentHeight: 50, maxHeight: 70, windowHeight: 0,
                                               fallbackWindowHeight: 0))
        #expect(ImplicitConsentNotice.scrolls(contentHeight: 300, maxHeight: 70, windowHeight: 0,
                                              fallbackWindowHeight: 0))
    }
}
