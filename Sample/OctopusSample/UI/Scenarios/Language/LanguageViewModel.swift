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

    let languages: [Language] = [
        Language(locale: Locale(identifier: "fr"), name: "French", comment: ""),
        Language(locale: Locale(identifier: "fr-BE"), name: "Belgian French", comment: ""),
        Language(locale: Locale(identifier: "en"), name: "English", comment: ""),
        Language(locale: Locale(identifier: "zh-Hant"), name: "Chinese", comment: "As this language is not supported yet, it will default to the base language (english)"),
        Language(locale: nil, name: "System", comment: "Set nil as overriden locale to let Octopus use default locale again."),
    ]

    @Published private(set) var selectedLanguage: Language?

    private let languageSetKey = "overridenLanguage"

    private let userDefaults = UserDefaults.standard

    init() {
        let selectedLanguageValue = userDefaults.string(forKey: languageSetKey)
        selectedLanguage = languages.first { $0.locale?.identifier == selectedLanguageValue }
    }

    func set(language: Language) {
        userDefaults.set(language.locale?.identifier, forKey: languageSetKey)
        selectedLanguage = language
        OctopusSDKProvider.instance.octopus.overrideDefaultLocale(with: language.locale)
    }
}
