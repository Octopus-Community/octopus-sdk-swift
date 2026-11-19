//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

/// Which tone the SDK texts take for a member, from the languages the community made informal and the language
/// the texts are displayed in.
struct TextToneTests {
    @Test func aCommunityThatSetNothingIsFormal() {
        #expect(TextTone(informalLanguages: [], languageIdentifier: "it") == .formal)
        #expect(TextTone(config: nil, languageIdentifier: "it") == .formal)
    }

    @Test func theLanguageOfTheMemberDecides() {
        // Italian informal, French left formal, as in the spec's test community.
        #expect(TextTone(informalLanguages: ["it"], languageIdentifier: "it") == .informal)
        #expect(TextTone(informalLanguages: ["it"], languageIdentifier: "fr") == .formal)
        #expect(TextTone(informalLanguages: ["it"], languageIdentifier: "en") == .formal)
    }

    @Test(arguments: ["fr-CA", "fr_FR", "FR", "fr-Latn-CA"])
    func theRegionOfTheDisplayedLanguageDoesNotMatter(languageIdentifier: String) {
        #expect(TextTone(informalLanguages: ["fr"], languageIdentifier: languageIdentifier) == .informal)
    }

    @Test func theRegionOfTheCommunityLanguageDoesNotMatter() {
        #expect(TextTone(informalLanguages: ["pt-PT"], languageIdentifier: "pt") == .informal)
        #expect(TextTone(informalLanguages: ["pt-BR"], languageIdentifier: "pt-PT") == .informal)
    }

    @Test(arguments: [
        // The SDK ships zh-Hans and zh-Hant: the community writes them with a script or with a region.
        ("zh-TW", "zh-Hant", TextTone.informal),
        ("zh-TW", "zh-Hant-HK", .informal),
        ("zh-HK", "zh-Hant", .informal),
        ("zh-Hant", "zh-TW", .informal),
        ("zh-CN", "zh-Hans", .informal),
        ("zh-Hans", "zh-CN", .informal),
        ("zh-CN", "zh-Hant", .formal),
        ("zh-TW", "zh-Hans", .formal),
        ("zh-Hant", "zh-CN", .formal),
        // A tag without script or region covers both.
        ("zh", "zh-Hant", .informal),
        ("zh", "zh-Hans", .informal),
        ("zh-TW", "zh", .informal),
    ])
    func chineseFollowsItsScript(informalLanguage: String, languageIdentifier: String, expected: TextTone) {
        #expect(TextTone(informalLanguages: [informalLanguage], languageIdentifier: languageIdentifier) == expected)
    }

    @Test func anEmptyCodeMatchesNothing() {
        #expect(TextTone(informalLanguages: [""], languageIdentifier: "") == .formal)
        #expect(TextTone(informalLanguages: [""], languageIdentifier: "fr") == .formal)
    }

    @Test func aLanguageCodeIsNotAPrefix() {
        // "f" is not French, and the Filipino "fil" is not Finnish.
        #expect(TextTone(informalLanguages: ["f"], languageIdentifier: "fr") == .formal)
        #expect(TextTone(informalLanguages: ["fi"], languageIdentifier: "fil") == .formal)
    }
}
