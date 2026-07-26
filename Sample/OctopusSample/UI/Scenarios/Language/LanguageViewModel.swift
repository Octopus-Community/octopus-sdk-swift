//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that sets the Octopus language
/// Some apps do not use the default way of handling the language which provide the system/app defined language by the
/// user. If you have a custom setting inside your app that does not set the system AppLanguage, you can call a function
/// of Octopus in order to customize the language used (so Octopus does not use the system language but yours instead).
class LanguageViewModel: ObservableObject {
    private var storage = [AnyCancellable]()

    struct Language: Equatable {
        let locale: Locale?
        let name: String
        let comment: String

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.locale?.identifier == rhs.locale?.identifier
        }
    }

    /// The languages supported by the SDK (Localizable.xcstrings), in the sheet's canonical column order.
    /// Arabic is right-to-left: selecting it also simulates an RTL host app (see `SampleLanguageManager`).
    let languages: [Language] = [
        Language(locale: Locale(identifier: "fr"), name: "French", comment: ""),
        Language(locale: Locale(identifier: "en"), name: "English", comment: ""),
        Language(locale: Locale(identifier: "de"), name: "German", comment: ""),
        Language(locale: Locale(identifier: "it"), name: "Italian", comment: ""),
        Language(locale: Locale(identifier: "es"), name: "Spanish", comment: ""),
        Language(locale: Locale(identifier: "pt"), name: "Portuguese", comment: ""),
        Language(locale: Locale(identifier: "tr"), name: "Turkish", comment: ""),
        Language(locale: Locale(identifier: "pl"), name: "Polish", comment: ""),
        Language(locale: Locale(identifier: "sv"), name: "Swedish", comment: ""),
        Language(locale: Locale(identifier: "fi"), name: "Finnish", comment: ""),
        Language(locale: Locale(identifier: "da"), name: "Danish", comment: ""),
        Language(locale: Locale(identifier: "nl"), name: "Dutch", comment: ""),
        Language(locale: Locale(identifier: "nb"), name: "Norwegian Bokmål", comment: ""),
        Language(locale: Locale(identifier: "ro"), name: "Romanian", comment: ""),
        Language(locale: Locale(identifier: "ar"), name: "Arabic", comment: "Right-to-left: also simulates an RTL host app."),
        Language(locale: Locale(identifier: "hi"), name: "Hindi", comment: ""),
        Language(locale: Locale(identifier: "th"), name: "Thai", comment: ""),
        Language(locale: Locale(identifier: "id"), name: "Indonesian", comment: ""),
        Language(locale: Locale(identifier: "ms"), name: "Malay", comment: ""),
        Language(locale: Locale(identifier: "vi"), name: "Vietnamese", comment: ""),
        Language(locale: Locale(identifier: "ru"), name: "Russian", comment: ""),
        Language(locale: Locale(identifier: "ja"), name: "Japanese", comment: ""),
        Language(locale: Locale(identifier: "zh-Hans"), name: "Chinese (Simplified)", comment: ""),
        Language(locale: Locale(identifier: "zh-Hant"), name: "Chinese (Traditional)", comment: ""),
        // Test cases (not shipped languages):
        Language(locale: Locale(identifier: "fr_BE"), name: "Belgian French", comment: "You should prefer fr-BE but this is to ensure that the sdk is correctly handling the _"),
        Language(locale: nil, name: "System", comment: "Set nil as overriden locale to let Octopus use default locale again."),
    ]

    @Published private(set) var selectedLanguage: Language?

    private let languageManager = SampleLanguageManager.instance

    init() {
        let selectedLocaleId = languageManager.overriddenLocale?.identifier
        selectedLanguage = languages.first { $0.locale?.identifier == selectedLocaleId }
    }

    func set(language: Language) {
        selectedLanguage = language
        languageManager.set(locale: language.locale)
    }
}
