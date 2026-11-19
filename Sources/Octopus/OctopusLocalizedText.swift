//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A text given by the app either for automatic translation or per language.
///
/// - ``autoTranslated(_:)``: one text, that Octopus translates automatically for every reader.
/// - ``perLanguage(_:defaultLanguage:)``: one text for each language the app has. A reader whose language is in
///   the list sees that text as it is; any other reader sees an automatic translation.
///
/// It is used for the label of the buttons the app attaches to a post: the call-to-action of a prefilled post
/// (``OctopusPrefilledPost/CTA``) and the button of a post linked to one of the app's objects (``ClientPost``).
public struct OctopusLocalizedText: Sendable, Equatable {
    /// The text to start from: the text itself when it is auto-translated, the text of the default language
    /// when it is given per language.
    public let defaultText: String

    /// The text of each language, as given. Empty when the text is auto-translated.
    public let texts: [Locale: String]

    /// The language of ``defaultText``, as given. `nil` when the text is auto-translated.
    public let defaultLanguage: Locale?

    /// The code sent to Octopus for ``defaultLanguage``, such as `en` or `pt-BR`.
    /// `nil` when the text is auto-translated.
    public let defaultLanguageCode: String?

    /// The text of each language by the code sent to Octopus for it, ``defaultLanguageCode`` included.
    /// Empty when the text is auto-translated.
    public let textsByLanguageCode: [String: String]

    private init(defaultText: String, texts: [Locale: String], defaultLanguage: Locale?,
                 defaultLanguageCode: String?, textsByLanguageCode: [String: String]) {
        self.defaultText = defaultText
        self.texts = texts
        self.defaultLanguage = defaultLanguage
        self.defaultLanguageCode = defaultLanguageCode
        self.textsByLanguageCode = textsByLanguageCode
    }

    /// Two values are equal when they send the same thing to Octopus: the same default text, and the same texts
    /// by language code with the same default one. The locales are compared through their codes, so
    /// `en_US` and `en-US` are the same language.
    public static func == (lhs: OctopusLocalizedText, rhs: OctopusLocalizedText) -> Bool {
        lhs.defaultText == rhs.defaultText
            && lhs.defaultLanguageCode == rhs.defaultLanguageCode
            && lhs.textsByLanguageCode == rhs.textsByLanguageCode
    }

    /// A text that Octopus translates automatically for every reader.
    ///
    /// - Parameter text: the text, in any language.
    public static func autoTranslated(_ text: String) -> OctopusLocalizedText {
        OctopusLocalizedText(defaultText: text, texts: [:], defaultLanguage: nil, defaultLanguageCode: nil,
                             textsByLanguageCode: [:])
    }

    /// A text given in each language the app has.
    ///
    /// A reader whose language is in `texts` sees that text as it is. Any other reader sees an automatic
    /// translation. Regions are not distinguished yet: a reader in Canadian French sees the `fr` text.
    ///
    /// Each language is sent as a code built from the parts of its `Locale`: the language, then the script and
    /// the region when the locale has them, joined with `-` (`fr`, `fr-FR`, `pt-BR`, `es-419`, `zh-Hans`). Anything
    /// else in the identifier is dropped (`en_US@calendar=japanese` gives `en-US`). The form of a code is not
    /// checked: the text of a language Octopus cannot read is accepted, and never displayed.
    ///
    /// The code is built from `Locale.identifier`, which the system may have rewritten. It can drop a script that
    /// the region implies (`Locale(identifier: "zh_Hant_TW")` has the identifier `zh_TW`, and gives `zh-TW`):
    /// write the identifier with hyphens (`Locale(identifier: "zh-Hant-TW")`) to keep that script. It also drops
    /// a script that is the usual one of the language (`sr-Cyrl` gives `sr`, `en-Latn-US` gives `en-US`) and
    /// replaces a language code that has a newer form (`iw` gives `he`), however the identifier is written.
    ///
    /// When the content is signed, your backend signs the codes that are sent, not the identifiers your app
    /// wrote. Give a language, with a region if needed and no script (`fr`, `pt-BR`, `zh-HK`): such a code is sent
    /// as it is written. Read ``textsByLanguageCode`` to see the codes that are sent.
    ///
    /// - Parameters:
    ///   - texts: the text of each language. Must not be empty, and no text can be empty or made of whitespace
    ///     only.
    ///   - defaultLanguage: the language of the text to start from for the languages that are not in `texts`,
    ///     like the default language of the app's own string files. Must be one of the languages of `texts`.
    /// - Throws: ``ValidationError`` when `texts` is empty, when a text is empty after trimming whitespace, when
    ///   a language has no language code (`Locale(identifier: "")`, or the undetermined `und`), when two
    ///   languages give the same code (`en_US` and `en-US`), or when the code of `defaultLanguage` is not one of
    ///   the codes of `texts`.
    public static func perLanguage(_ texts: [Locale: String],
                                   defaultLanguage: Locale) throws -> OctopusLocalizedText {
        guard !texts.isEmpty else { throw ValidationError(kind: .emptyTexts) }

        var textsByCode: [String: String] = [:]
        // Sorted so that the error reported does not depend on the order of the dictionary.
        for (locale, text) in texts.sorted(by: { $0.key.identifier < $1.key.identifier }) {
            guard let code = languageCode(of: locale) else {
                throw ValidationError(kind: .emptyLanguage)
            }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError(kind: .blankText, languageCode: code)
            }
            guard textsByCode.updateValue(text, forKey: code) == nil else {
                throw ValidationError(kind: .duplicateLanguage, languageCode: code)
            }
        }

        guard let defaultCode = languageCode(of: defaultLanguage) else {
            throw ValidationError(kind: .emptyLanguage)
        }
        guard let defaultText = textsByCode[defaultCode] else {
            throw ValidationError(kind: .defaultLanguageMissing, languageCode: defaultCode)
        }
        return OctopusLocalizedText(defaultText: defaultText, texts: texts, defaultLanguage: defaultLanguage,
                                    defaultLanguageCode: defaultCode, textsByLanguageCode: textsByCode)
    }

    /// The code sent to Octopus for a locale: its language, then its script and its region when the identifier
    /// has them, joined with `-`. `nil` when the locale has no language, or the undetermined `und`.
    ///
    /// The parts are read from the identifier with the same API on every OS version. The properties of `Locale`
    /// are not used: from iOS 16, `locale.language.script` gives the script the system infers for the language
    /// (`Latn` for `fr_FR`), which the app did not give. The identifier is the one `Locale` holds, which the
    /// system may have rewritten when the locale was built (`zh_Hant_TW` becomes `zh_TW`).
    static func languageCode(of locale: Locale) -> String? {
        let components = Locale.components(fromIdentifier: locale.identifier)
        // `und` is the BCP-47 code of an undetermined language: no reader has it, so a text sent under it would
        // never be displayed. It is refused like a locale without language, as Android's
        // `Locale.forLanguageTag("und")` gives no language.
        guard let language = components[NSLocale.Key.languageCode.rawValue], !language.isEmpty,
              language.lowercased() != "und" else { return nil }
        let parts = [language,
                     components[NSLocale.Key.scriptCode.rawValue],
                     components[NSLocale.Key.countryCode.rawValue]]
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "-")
    }

    /// Thrown by ``OctopusLocalizedText/perLanguage(_:defaultLanguage:)`` when the texts cannot be used.
    public struct ValidationError: Error, Equatable, CustomDebugStringConvertible {
        /// What is wrong with the texts.
        #if hasAttribute(nonexhaustive)
        @nonexhaustive
        #endif
        public enum Kind: Sendable, Equatable {
            /// No text was given.
            case emptyTexts
            /// A text is empty, or made of whitespace only.
            case blankText
            /// A language has no language code, like `Locale(identifier: "")` or the undetermined `und`.
            case emptyLanguage
            /// Two languages give the same code, like `en_US` and `en-US`.
            case duplicateLanguage
            /// The default language is not one of the languages of the texts.
            case defaultLanguageMissing
        }

        /// What is wrong with the texts.
        public let kind: Kind

        /// The language code the error is about, as it would have been sent to Octopus. `nil` when the error is
        /// not about one language (``Kind/emptyTexts``, ``Kind/emptyLanguage``).
        public let languageCode: String?

        /// Creates the error.
        ///
        /// - Parameters:
        ///   - kind: what is wrong with the texts.
        ///   - languageCode: the language code the error is about, if any.
        public init(kind: Kind, languageCode: String? = nil) {
            self.kind = kind
            self.languageCode = languageCode
        }

        public var debugDescription: String {
            let prefix = "OctopusLocalizedText.ValidationError.\(kind): "
            let code = languageCode ?? ""
            switch kind {
            case .emptyTexts:
                return prefix + "`texts` must hold at least one text."
            case .blankText:
                return prefix + "the text of `\(code)` must not be empty."
            case .emptyLanguage:
                return prefix + "a language has no language code."
            case .duplicateLanguage:
                return prefix + "two languages of `texts` give the code `\(code)`."
            case .defaultLanguageMissing:
                return prefix + "`defaultLanguage` (`\(code)`) must be one of the languages of `texts`."
            }
        }
    }
}

extension OctopusLocalizedText {
    /// The texts given per language, as the core sends and signs them: the one of the default language travels
    /// as the text itself, the others next to it. `nil` when the text is auto-translated.
    var corePerLanguageLabels: PerLanguageLabels? {
        defaultLanguageCode.map { code in
            PerLanguageLabels(defaultLanguageCode: code, textsByLanguageCode: textsByLanguageCode)
        }
    }
}
