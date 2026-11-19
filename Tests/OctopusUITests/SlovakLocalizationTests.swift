//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Slovak is generated from the localization sheet like the other languages; these check that the compiled catalog
/// ships it, and that a plural the sheet gives a `few` row keeps the 2–4 form Slovak needs, which English does not have.
struct SlovakLocalizationTests {
    static let locale = Locale(identifier: "sk")

    @Test func catalogShipsSlovak() {
        #expect(Bundle.module.localizations.contains("sk"))
    }

    @Test func simpleStringIsTranslated() {
        #expect(L10n("Common.Cancel", locale: Self.locale) == "Zrušiť")
    }

    /// Plural keys are shown through `Text(_:bundle:)`, which picks the plural form with the environment's locale,
    /// so the format is applied with the Slovak locale here rather than through `L10n` (which uses the current one).
    @Test(arguments: [
        (1, "Zobraziť 1 odpoveď"),
        (3, "Zobraziť 3 odpovede"),
        (5, "Zobraziť 5 odpovedí"),
    ])
    func repliesCountUsesSlovakPluralForms(count: Int, expected: String) throws {
        let path = try #require(Bundle.module.path(forResource: "sk", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: "Reply.See_count:%lld", value: nil, table: nil)
        #expect(String(format: format, locale: Self.locale, count) == expected)
    }
}
