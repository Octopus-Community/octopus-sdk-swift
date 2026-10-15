//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// A language the SDK can be forced to, through `overrideDefaultLocale(with:)`.
struct SDKLanguage: Equatable, Identifiable {
    /// The locale identifier handed to the SDK, also the suffix of the row's test id.
    let code: String
    /// Its English name: the sample itself is not localized.
    let name: String
    /// One line on what is special about it, empty for most.
    var comment: String = ""

    var id: String { code }
    var locale: Locale { Locale(identifier: code) }
}

/// The languages the SDK ships (`Localizable.xcstrings`), in the sheet's canonical column order.
enum SDKLanguages {
    static let shipped: [SDKLanguage] = [
        SDKLanguage(code: "fr", name: "French"),
        SDKLanguage(code: "en", name: "English"),
        SDKLanguage(code: "de", name: "German"),
        SDKLanguage(code: "it", name: "Italian"),
        SDKLanguage(code: "es", name: "Spanish"),
        SDKLanguage(code: "pt", name: "Portuguese"),
        SDKLanguage(code: "tr", name: "Turkish"),
        SDKLanguage(code: "pl", name: "Polish"),
        SDKLanguage(code: "sv", name: "Swedish"),
        SDKLanguage(code: "fi", name: "Finnish"),
        SDKLanguage(code: "da", name: "Danish"),
        SDKLanguage(code: "nl", name: "Dutch"),
        SDKLanguage(code: "nb", name: "Norwegian Bokmål"),
        SDKLanguage(code: "ro", name: "Romanian"),
        SDKLanguage(code: "ar", name: "Arabic", comment: "Right-to-left: also simulates an RTL host app."),
        SDKLanguage(code: "hi", name: "Hindi"),
        SDKLanguage(code: "th", name: "Thai"),
        SDKLanguage(code: "id", name: "Indonesian"),
        SDKLanguage(code: "ms", name: "Malay"),
        SDKLanguage(code: "vi", name: "Vietnamese"),
        SDKLanguage(code: "ru", name: "Russian"),
        SDKLanguage(code: "ja", name: "Japanese"),
        SDKLanguage(code: "zh-Hans", name: "Chinese (Simplified)"),
        SDKLanguage(code: "zh-Hant", name: "Chinese (Traditional)"),
    ]

    /// The languages Settings › Language offers, in the Android sample's list and order. Every one is shipped by
    /// the iOS SDK; the other shipped languages stay reachable through `summary(for:)` when set another way.
    static let settingsCodes = ["en", "fr", "de", "it", "pl", "pt", "es", "sv", "tr"]

    static var settingsList: [SDKLanguage] {
        settingsCodes.compactMap { code in shipped.first { $0.code == code } }
    }

    /// The Settings row value for an override: "Follow system", the language name and its code, or the bare
    /// identifier of a test locale that is not a shipped language.
    static func summary(for identifier: String?) -> String {
        guard let identifier, !identifier.isEmpty else { return "Follow system" }
        guard let language = shipped.first(where: { $0.code == identifier }) else { return identifier }
        return "\(language.name) (\(language.code))"
    }
}
