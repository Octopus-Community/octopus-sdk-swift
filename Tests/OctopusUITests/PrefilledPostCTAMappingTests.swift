//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Octopus
import OctopusCore
@testable import OctopusUI

/// The CTA of a prefilled post as the editor hands it to the core: the labels the app gave per language must
/// travel with it, or the post would silently be sent with an auto-translated label.
struct PrefilledPostCTAMappingTests {
    private let url = URL(string: "myapp://item/42")!

    @Test func perLanguageLabelMapsToTheDefaultLabelAndTheOtherLabels() throws {
        let cta = try OctopusPrefilledPost.CTA(url: url, localizedLabel: .perLanguage(
            [Locale(identifier: "en"): "Start", Locale(identifier: "fr"): "Démarrer",
             Locale(identifier: "es-419"): "Empezar"],
            defaultLanguage: Locale(identifier: "en")))

        #expect(WritableCTA(cta) == WritableCTA(
            url: url, label: "Start",
            perLanguageLabels: PerLanguageLabels(
                defaultLanguageCode: "en", translations: ["fr": "Démarrer", "es-419": "Empezar"])))
    }

    @Test func autoTranslatedLabelMapsToNoPerLanguageLabels() throws {
        let cta = try OctopusPrefilledPost.CTA(url: url, localizedLabel: .autoTranslated("Start"))

        #expect(WritableCTA(cta) == WritableCTA(url: url, label: "Start", perLanguageLabels: nil))
    }
}
