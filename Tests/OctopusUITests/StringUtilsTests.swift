//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
class StringUtilsTests {
    @Test func testFormattedCount() async throws {
        #expect(String.formattedCount(9) == "9")
        #expect(String.formattedCount(99) == "99")
        #expect(String.formattedCount(999) == "999")
        #expect(String.formattedCount(9_999) == "9.9K")
        #expect(String.formattedCount(99_999) == "99K")
        #expect(String.formattedCount(999_999) == "999K")
        #expect(String.formattedCount(9_999_999) == "9.9M")
        #expect(String.formattedCount(99_999_999) == "99M")
        #expect(String.formattedCount(999_999_999) == "999M")
        #expect(String.formattedCount(9_999_999_999) == "9.9B")
        #expect(String.formattedCount(99_999_999_999) == "99B")
        #expect(String.formattedCount(999_999_999_999) == "999B")

        #expect(String.formattedCount(1) == "1")
        #expect(String.formattedCount(1000) == "1K")
        #expect(String.formattedCount(1001) == "1K")
        #expect(String.formattedCount(1250) == "1.2K")
        #expect(String.formattedCount(1251) == "1.2K")
        #expect(String.formattedCount(12551) == "12K")
        #expect(String.formattedCount(120551) == "120K")
        #expect(String.formattedCount(1205510) == "1.2M")
        #expect(String.formattedCount(12055100) == "12M")
        #expect(String.formattedCount(120551000) == "120M")
        #expect(String.formattedCount(1205510000) == "1.2B")
    }

    @Test(arguments: [
        (0, "0"), (1, "1"), (999, "999"),
        (1_000, "1K"), (1_049, "1K"), (1_250, "1.2K"), (1_299, "1.2K"), (9_999, "9.9K"),
        (12_400, "12K"), (123_456, "123K"), (999_999, "999K"),
        (1_250_000, "1.2M"), (12_400_000, "12M"), (1_500_000_000, "1.5B")
    ])
    func formattedCountInEnglish(count: Int, expected: String) {
        #expect(String.formattedCount(count, locale: Locale(identifier: "en_US")) == expected)
    }

    @Test(arguments: [
        (999, "999"),
        (1_000, "1K"), (1_250, "1,2K"), (9_999, "9,9K"),
        (12_400, "12K"), (999_999, "999K"),
        (1_250_000, "1,2M"), (12_400_000, "12M"), (1_500_000_000, "1,5B")
    ])
    func formattedCountInFrench(count: Int, expected: String) {
        #expect(String.formattedCount(count, locale: Locale(identifier: "fr_FR")) == expected)
        #expect(String.formattedCount(count, locale: Locale(identifier: "fr_CA")) == expected)
    }

    /// Every language keeps "K", "M" and "B" and only writes its own decimal separator.
    @Test func formattedCountUsesTheDecimalSeparatorOfTheLocale() {
        let german = Locale(identifier: "de_DE")
        #expect(String.formattedCount(1_250, locale: german) == "1,2K")
        #expect(String.formattedCount(12_400, locale: german) == "12K")
        #expect(String.formattedCount(1_250_000, locale: german) == "1,2M")
    }
}
