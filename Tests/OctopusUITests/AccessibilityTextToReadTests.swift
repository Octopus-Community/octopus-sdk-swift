//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI
import OctopusCore

/// Unit-tests for `accessibilityTextToRead`, the VoiceOver rendition of a post's body in
/// `PostSummaryView`. Extracted as a pure function (same pattern as `canOpenHostProfile`) so the
/// label's expansion-following behavior — otherwise buried in `accessibilityDescription`, which has
/// no SwiftUI test harness in this repo — stays independently unit-testable.
@Suite
struct AccessibilityTextToReadTests {
    /// 250 'a's: longer than the 200-char truncation budget, with no line breaks, so only the
    /// character limit is exercised.
    private static let longBody = String(repeating: "a", count: 250)

    @Test func ellipsizedLongBody_readsTheShortenedTextWithATrailingEllipsis() {
        let text = TranslatableText(originalText: Self.longBody, originalLanguage: nil)
        let result = accessibilityTextToRead(text: text, ellipsize: true)
        #expect(result == String(Self.longBody.prefix(200)) + "...")
    }

    @Test func expandedLongBody_readsTheFullTextWithNoEllipsis() {
        let text = TranslatableText(originalText: Self.longBody, originalLanguage: nil)
        let result = accessibilityTextToRead(text: text, ellipsize: false)
        #expect(result == Self.longBody)
    }

    @Test func shortBody_readsIdenticallyRegardlessOfEllipsize() {
        let text = TranslatableText(originalText: "Short enough", originalLanguage: nil)
        let ellipsized = accessibilityTextToRead(text: text, ellipsize: true)
        let expanded = accessibilityTextToRead(text: text, ellipsize: false)
        #expect(ellipsized == "Short enough")
        #expect(expanded == "Short enough")
        #expect(!ellipsized.hasSuffix("..."))
        #expect(!expanded.hasSuffix("..."))
    }

    @Test func translatedText_readsTheTranslatedVariant() {
        let text = TranslatableText(
            originalText: "Un texte",
            originalLanguage: "fr",
            translatedText: "A text")
        let result = accessibilityTextToRead(text: text, ellipsize: true)
        #expect(result == "A text")
    }
}
