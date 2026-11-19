//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// How the SDK texts address the member: formally ("vous", "Sie", "Lei"…) or informally ("tu", "du", "tu"…).
///
/// Only the texts that differ between the two have a version per tone. Languages without a polite form (English,
/// Swedish…) carry the same text in both.
public enum TextTone: Sendable, Equatable {
    /// The polite form. What every community shows unless its back-office says otherwise.
    case formal
    /// The familiar form.
    case informal

    /// The tone of the SDK texts for a member who reads them in `languageIdentifier`.
    ///
    /// - Parameters:
    ///   - informalLanguages: the community languages switched to the informal tone (BCP-47 codes, like `it` or
    ///     `zh-TW`).
    ///   - languageIdentifier: the language the SDK texts are displayed in (`fr`, `fr-CA`, `zh-Hans`…).
    public init(informalLanguages: [String], languageIdentifier: String) {
        let displayed = LanguageTag(languageIdentifier)
        let isInformal = informalLanguages.contains { LanguageTag($0).matches(displayed) }
        self = isInformal ? .informal : .formal
    }

    /// The tone of the SDK texts for a member of a community configured with `config`, who reads them in
    /// `languageIdentifier`. Formal when the config is not known yet.
    public init(config: CommunityConfig?, languageIdentifier: String) {
        self.init(informalLanguages: config?.informalLanguages ?? [], languageIdentifier: languageIdentifier)
    }
}

/// The parts of a language tag that decide which translation is displayed.
///
/// The region does not choose a tone (a community informal in `fr` is informal for a `fr-CA` reader too), except
/// for Chinese, where it stands for the script: `zh-TW` and `zh-Hant` are the same texts, `zh-CN` and `zh-Hans`
/// are the other ones.
private struct LanguageTag {
    let language: String
    /// `hans` or `hant` for Chinese, when the tag tells it; `nil` otherwise.
    let chineseScript: String?

    init(_ tag: String) {
        let subtags = tag.lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map(String.init)
        language = subtags.first ?? ""
        guard language == "zh" else {
            chineseScript = nil
            return
        }
        let rest = subtags.dropFirst()
        if let script = rest.first(where: { $0 == "hans" || $0 == "hant" }) {
            chineseScript = script
        } else if let region = rest.first(where: { $0.count == 2 }) {
            chineseScript = ["tw", "hk", "mo"].contains(region) ? "hant" : "hans"
        } else {
            chineseScript = nil
        }
    }

    /// Whether a community language written as `self` covers the displayed language `other`. A tag that does not
    /// tell the Chinese script covers both.
    func matches(_ other: LanguageTag) -> Bool {
        guard !language.isEmpty, language == other.language else { return false }
        guard let chineseScript, let otherScript = other.chineseScript else { return true }
        return chineseScript == otherScript
    }
}
