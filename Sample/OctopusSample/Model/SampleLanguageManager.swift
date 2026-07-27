//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// Internal-demo-only holder for the language override chosen in the "Override Language" scenario.
///
/// It persists the chosen locale, forwards it to the SDK (`overrideDefaultLocale`), and — for testing
/// convenience — exposes the layout direction that the chosen language implies. The SDK itself always
/// follows the **host app's** layout direction (it never flips based on its own content language), so
/// to preview RTL (Arabic) without switching the whole device to an RTL language, the sample simulates
/// an RTL host by forcing the layout direction on the Octopus view (see `OctopusUIView`).
class SampleLanguageManager: ObservableObject {
    static let instance = SampleLanguageManager()

    private let storageKey = "overridenLanguage"

    @Published private(set) var overriddenLocale: Locale?

    /// The layout direction implied by the overridden language, or `nil` when no override is set
    /// (in which case the app's natural direction should be inherited untouched).
    var simulatedLayoutDirection: LayoutDirection? {
        guard let code = overriddenLocale?.languageCode?.lowercased() else { return nil }
        // Languages written right-to-left. Only Arabic is in the SDK scope today; the others are
        // listed so the simulation is correct if they're ever added to the picker.
        let rtlLanguages: Set<String> = ["ar", "he", "iw", "fa", "ur"]
        return rtlLanguages.contains(code) ? .rightToLeft : .leftToRight
    }

    private init() {
        let identifier = UserDefaults.standard.string(forKey: storageKey)
        overriddenLocale = identifier.map { Locale(identifier: $0) }
        // Re-apply the persisted override on launch so it survives app restarts.
        OctopusSDKProvider.instance.octopus.overrideDefaultLocale(with: overriddenLocale)
    }

    func set(locale: Locale?) {
        UserDefaults.standard.set(locale?.identifier, forKey: storageKey)
        overriddenLocale = locale
        OctopusSDKProvider.instance.octopus.overrideDefaultLocale(with: locale)
    }
}

private extension Locale {
    /// `languageCode` is deprecated on iOS 16+ in favor of `language.languageCode`; use whichever is
    /// available so the sample builds warning-free on the SDK's iOS 13+ range.
    var languageCode: String? {
        if #available(iOS 16.0, *) {
            return language.languageCode?.identifier
        } else {
            return (self as NSLocale).object(forKey: .languageCode) as? String
        }
    }
}
