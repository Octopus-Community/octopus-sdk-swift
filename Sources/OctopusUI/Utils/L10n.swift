//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

fileprivate extension Locale {
    /// Example:
    /// Locale(identifier: "fr_CA") → ["fr-CA", "fr"]
    var languageFallbacks: [String] {
        var fallbacks: [String] = []

        // Preferred modern API (iOS 16+)
        if #available(iOS 16.0, *) {
            if let languageCode = language.languageCode?.identifier {
                if let regionCode = region?.identifier {
                    fallbacks.append("\(languageCode)-\(regionCode)")
                }
                fallbacks.append(languageCode)
            }
        } else {
            // iOS 15 and below
            let languageCode = self.languageCode
            let regionCode = self.regionCode

            if let languageCode, let regionCode {
                fallbacks.append("\(languageCode)-\(regionCode)")
            }
            if let languageCode {
                fallbacks.append(languageCode)
            }
        }

        return fallbacks
    }
}


/// Transforms a localized key into a localized string (taken from the module bundle)
/// - Parameter key: the key (can be found in Localizable.xcstrings)
/// - Returns: a localized string
/// - Note: This can be useful when the SwiftUI view has no API to set the bundle. However, it should be avoided
///   because it disables the Localizable.xcstrings file capacity to point to the line where the string is used.
func L10n(_ key: String, locale: Locale?, _ args: any CVarArg...) -> String {
    var forcedLanguageFormat: String?
    if let languageFallbacks = locale?.languageFallbacks, !languageFallbacks.isEmpty {
        for code in languageFallbacks {
            if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                let value = bundle.localizedString(forKey: key, value: nil, table: nil)
                if value != key {
                    forcedLanguageFormat = value
                    break
                }
            }
        }
    }

    let format = forcedLanguageFormat ?? Bundle.module.localizedString(forKey: key, value: nil, table: nil)

    return String.localizedStringWithFormat(format, args)
}
