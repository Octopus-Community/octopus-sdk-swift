//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The labels of a button given by the app per language, next to the label of the default language that the
/// button carries as its text.
public struct PerLanguageLabels: Sendable, Equatable {
    /// The language code of the button's text.
    public let defaultLanguageCode: String
    /// The labels of the other languages, by language code. The default language is not part of it.
    public let translations: [String: String]

    public init(defaultLanguageCode: String, translations: [String: String]) {
        self.defaultLanguageCode = defaultLanguageCode
        self.translations = translations
    }

    /// Creates the labels from the label of every language, the default one included: it is the text of the
    /// button, so it is left out of `translations`. The signed content depends on it.
    public init(defaultLanguageCode: String, textsByLanguageCode: [String: String]) {
        self.init(defaultLanguageCode: defaultLanguageCode,
                  translations: textsByLanguageCode.filter { $0.key != defaultLanguageCode })
    }
}

extension PerLanguageLabels {
    /// Sets the language of the text and the other labels on a proto CTA whose text is the default label.
    func fill(_ cta: inout Com_Octopuscommunity_CTA) {
        cta.textLanguage = defaultLanguageCode
        cta.textTranslations = translations
    }

    /// The `ctaTextTranslations` value of a signed content: a compact JSON object of the other languages' labels,
    /// slashes unescaped. `nil` when there is no other language: the key is then left out.
    ///
    /// The keys are sorted by the bytes of their UTF-8 form, which is the order the back and the Android SDK use.
    /// The object is built by hand because the sorted keys of `JSONEncoder` do not give that order on every OS
    /// version: older ones compare without case and read digits as numbers, and the codes mix cases (`zh-HK`
    /// comes before `zh-Hans` in bytes, after it without case).
    func signedTranslationsJSON(encoder: JSONEncoder) throws -> Data? {
        guard !translations.isEmpty else { return nil }
        let sortedCodes = translations.keys.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        var json = Data("{".utf8)
        for (index, code) in sortedCodes.enumerated() {
            if index > 0 { json.append(UInt8(ascii: ",")) }
            json.append(try encoder.encode(code))
            json.append(UInt8(ascii: ":"))
            json.append(try encoder.encode(translations[code] ?? ""))
        }
        json.append(UInt8(ascii: "}"))
        return json
    }
}
