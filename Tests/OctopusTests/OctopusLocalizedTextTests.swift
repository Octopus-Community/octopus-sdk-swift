//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import Octopus
import OctopusCore

// Both modules declare a `ClientPost`: the tests exercise the public one.
private typealias ClientPost = Octopus.ClientPost

struct OctopusLocalizedTextTests {
    private typealias ValidationError = OctopusLocalizedText.ValidationError

    private func locale(_ identifier: String) -> Locale { Locale(identifier: identifier) }

    // MARK: - Auto-translated

    @Test func autoTranslatedCarriesTheTextOnly() {
        let text = OctopusLocalizedText.autoTranslated("Start")
        #expect(text.defaultText == "Start")
        #expect(text.defaultLanguageCode == nil)
        #expect(text.defaultLanguage == nil)
        #expect(text.texts.isEmpty)
        #expect(text.textsByLanguageCode.isEmpty)
        #expect(text.corePerLanguageLabels == nil)
    }

    // MARK: - Per language

    @Test func perLanguageKeepsTheDefaultLabelAsTextAndTheOthersAsTranslations() throws {
        let text = try OctopusLocalizedText.perLanguage(
            [locale("en"): "Start", locale("fr"): "Démarrer", locale("es"): "Empezar"],
            defaultLanguage: locale("en"))
        #expect(text.defaultText == "Start")
        #expect(text.defaultLanguageCode == "en")
        #expect(text.defaultLanguage == locale("en"))
        #expect(text.texts == [locale("en"): "Start", locale("fr"): "Démarrer", locale("es"): "Empezar"])
        #expect(text.textsByLanguageCode == ["en": "Start", "fr": "Démarrer", "es": "Empezar"])
        #expect(text.corePerLanguageLabels == PerLanguageLabels(
            defaultLanguageCode: "en", translations: ["fr": "Démarrer", "es": "Empezar"]))
    }

    @Test func perLanguageAcceptsASingleLanguage() throws {
        let text = try OctopusLocalizedText.perLanguage([locale("fr"): "Démarrer"], defaultLanguage: locale("fr"))
        #expect(text.defaultText == "Démarrer")
        #expect(text.defaultLanguageCode == "fr")
        #expect(text.textsByLanguageCode == ["fr": "Démarrer"])
        #expect(text.corePerLanguageLabels == PerLanguageLabels(defaultLanguageCode: "fr", translations: [:]))
    }

    @Test func perLanguageMatchesTheDefaultLanguageOnItsCode() throws {
        let text = try OctopusLocalizedText.perLanguage(
            [locale("en-US"): "Start", locale("fr"): "Démarrer"], defaultLanguage: locale("en_US"))
        #expect(text.defaultText == "Start")
        #expect(text.defaultLanguageCode == "en-US")
    }

    @Test func perLanguageAcceptsCodesOfTheSameLanguageAndUnknownCodes() throws {
        let text = try OctopusLocalizedText.perLanguage(
            [locale("en"): "Start", locale("en-US"): "Start now", locale("zh-Hans"): "开始",
             locale("zh-Hant"): "開始", locale("xx-YY"): "Unknown"],
            defaultLanguage: locale("en"))
        #expect(text.textsByLanguageCode == [
            "en": "Start", "en-US": "Start now", "zh-Hans": "开始", "zh-Hant": "開始", "xx-YY": "Unknown"
        ])
    }

    @Test func perLanguageAcceptsALabelOver28Characters() throws {
        let label = String(repeating: "a", count: 60)
        let text = try OctopusLocalizedText.perLanguage([locale("en"): label], defaultLanguage: locale("en"))
        #expect(text.defaultText == label)
    }

    @Test func valuesAreEqualWhenTheySendTheSameTexts() throws {
        let text = try OctopusLocalizedText.perLanguage(
            [locale("en_US"): "Start", locale("fr"): "Démarrer"], defaultLanguage: locale("en_US"))
        let sameCodes = try OctopusLocalizedText.perLanguage(
            [locale("en-US"): "Start", locale("fr"): "Démarrer"], defaultLanguage: locale("en-US"))
        #expect(text == sameCodes)
        #expect(text != (try OctopusLocalizedText.perLanguage(
            [locale("en_US"): "Start", locale("fr"): "Commencer"], defaultLanguage: locale("en_US"))))
        #expect(text != (try OctopusLocalizedText.perLanguage(
            [locale("en_US"): "Start", locale("fr"): "Démarrer"], defaultLanguage: locale("fr"))))
        #expect(text != .autoTranslated("Start"))
    }

    // MARK: - Validation

    @Test func perLanguageRefusesAnEmptyList() {
        #expect(throws: ValidationError(kind: .emptyTexts)) {
            _ = try OctopusLocalizedText.perLanguage([:], defaultLanguage: locale("en"))
        }
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func perLanguageRefusesABlankText(label: String) {
        #expect(throws: ValidationError(kind: .blankText, languageCode: "fr")) {
            _ = try OctopusLocalizedText.perLanguage(
                [locale("en"): "Start", locale("fr"): label], defaultLanguage: locale("en"))
        }
    }

    @Test func perLanguageRefusesALanguageWithoutLanguageCode() {
        #expect(throws: ValidationError(kind: .emptyLanguage)) {
            _ = try OctopusLocalizedText.perLanguage(
                [locale("en"): "Start", locale(""): "Nothing"], defaultLanguage: locale("en"))
        }
        #expect(throws: ValidationError(kind: .emptyLanguage)) {
            _ = try OctopusLocalizedText.perLanguage([locale("en"): "Start"], defaultLanguage: locale(""))
        }
    }

    @Test func perLanguageRefusesTwoLanguagesGivingTheSameCode() {
        #expect(throws: ValidationError(kind: .duplicateLanguage, languageCode: "en-US")) {
            _ = try OctopusLocalizedText.perLanguage(
                [locale("en_US"): "Start", locale("en-US"): "Start now"], defaultLanguage: locale("en_US"))
        }
    }

    @Test func perLanguageRefusesADefaultLanguageThatIsNotInTheTexts() {
        #expect(throws: ValidationError(kind: .defaultLanguageMissing, languageCode: "en-US")) {
            _ = try OctopusLocalizedText.perLanguage([locale("en"): "Start"], defaultLanguage: locale("en-US"))
        }
    }

    @Test(arguments: [
        ValidationError(kind: .emptyTexts),
        ValidationError(kind: .blankText, languageCode: "fr"),
        ValidationError(kind: .emptyLanguage),
        ValidationError(kind: .duplicateLanguage, languageCode: "en-US"),
        ValidationError(kind: .defaultLanguageMissing, languageCode: "en-US")
    ])
    func validationErrorDescribesItself(error: OctopusLocalizedText.ValidationError) {
        #expect(error.debugDescription.hasPrefix("OctopusLocalizedText.ValidationError.\(error.kind): "))
        if let code = error.languageCode {
            #expect(error.debugDescription.contains("`\(code)`"))
        }
    }

    // MARK: - Language code

    /// Only the rows that give the same code on every OS version: an identifier that names the default script of
    /// its region (`zh_Hant_TW`) is left out, the system may drop that script when it builds the `Locale`.
    @Test(arguments: [
        ("fr", "fr"),
        ("fr_FR", "fr-FR"),
        ("fr-FR", "fr-FR"),
        ("pt-BR", "pt-BR"),
        ("pt_BR", "pt-BR"),
        ("es-419", "es-419"),
        ("es_419", "es-419"),
        ("zh-Hans", "zh-Hans"),
        ("zh_Hans", "zh-Hans"),
        ("zh-HK", "zh-HK"),
        ("en_US@calendar=japanese", "en-US"),
        ("id_ID", "id-ID"),
        ("xx-YY", "xx-YY")
    ])
    func languageCodeIsBuiltFromTheLanguageTheScriptAndTheRegion(identifier: String, expectedCode: String) {
        #expect(OctopusLocalizedText.languageCode(of: Locale(identifier: identifier)) == expectedCode)
    }

    @Test func languageCodeIsNilWithoutLanguage() {
        #expect(OctopusLocalizedText.languageCode(of: Locale(identifier: "")) == nil)
    }

    @Test(arguments: ["und", "und-FR", "und_FR", "UND"])
    func languageCodeIsNilForTheUndeterminedLanguage(identifier: String) {
        #expect(OctopusLocalizedText.languageCode(of: Locale(identifier: identifier)) == nil)
    }

    @Test func perLanguageRefusesTheUndeterminedLanguage() {
        #expect(throws: OctopusLocalizedText.ValidationError(kind: .emptyLanguage)) {
            _ = try OctopusLocalizedText.perLanguage([locale("en"): "Start", locale("und"): "Start"],
                                                     defaultLanguage: locale("en"))
        }
        #expect(throws: OctopusLocalizedText.ValidationError(kind: .emptyLanguage)) {
            _ = try OctopusLocalizedText.perLanguage([locale("en"): "Start"], defaultLanguage: locale("und"))
        }
    }

    @Test func languageCodeKeepsALanguageThatOnlyStartsWithUnd() {
        #expect(OctopusLocalizedText.languageCode(of: Locale(identifier: "unr")) == "unr")
    }

    // MARK: - Prefilled post CTA

    @Test func ctaWithPerLanguageLabelExposesTheDefaultLabel() throws {
        let localizedLabel = try OctopusLocalizedText.perLanguage(
            [locale("en"): "Start", locale("fr"): "Démarrer"], defaultLanguage: locale("en"))
        let cta = try OctopusPrefilledPost.CTA(url: URL(string: "myapp://item/42")!, localizedLabel: localizedLabel)
        #expect(cta.label == "Start")
        #expect(cta.localizedLabel == localizedLabel)
    }

    @Test func ctaWithAutoTranslatedLabelRefusesAnEmptyLabel() {
        #expect(throws: OctopusPrefilledPost.ValidationError.ctaLabelEmpty) {
            _ = try OctopusPrefilledPost.CTA(url: URL(string: "https://example.com")!,
                                             localizedLabel: .autoTranslated("  "))
        }
    }

    @Test func ctasThatDifferOnlyByTheirTranslationsAreNotEqual() throws {
        let url = URL(string: "myapp://item/42")!
        let french = try OctopusPrefilledPost.CTA(url: url, localizedLabel: .perLanguage(
            [locale("en"): "Start", locale("fr"): "Démarrer"], defaultLanguage: locale("en")))
        let spanish = try OctopusPrefilledPost.CTA(url: url, localizedLabel: .perLanguage(
            [locale("en"): "Start", locale("es"): "Empezar"], defaultLanguage: locale("en")))
        #expect(french != spanish)
        #expect(french != (try OctopusPrefilledPost.CTA(url: url, localizedLabel: .autoTranslated("Start"))))
    }

    // MARK: - Client post

    @Test func clientPostWithPerLanguageButtonMapsItsLabelsToCore() throws {
        let button = try OctopusLocalizedText.perLanguage(
            [locale("en"): "Discuss", locale("es"): "Comentar"], defaultLanguage: locale("en"))
        let post = ClientPost(clientObjectId: "object-id", text: "A text long enough",
                              viewClientObjectButton: button)

        #expect(post.viewClientObjectButtonText == "Discuss")
        #expect(post.viewClientObjectButton == button)
        #expect(post.coreValue.viewClientObjectButtonText == "Discuss")
        #expect(post.coreValue.viewClientObjectButtonLabels == PerLanguageLabels(
            defaultLanguageCode: "en", translations: ["es": "Comentar"]))
    }

    @Test func clientPostWithAutoTranslatedButtonMapsNoLabelToCore() {
        let post = ClientPost(clientObjectId: "object-id", text: "A text long enough",
                              viewClientObjectButton: .autoTranslated("Discuss"))
        #expect(post.viewClientObjectButtonText == "Discuss")
        #expect(post.coreValue.viewClientObjectButtonText == "Discuss")
        #expect(post.coreValue.viewClientObjectButtonLabels == nil)
    }

    @Test func clientPostWithoutButtonHasNoButtonText() {
        let post = ClientPost(clientObjectId: "object-id", text: "A text long enough", viewClientObjectButton: nil)
        #expect(post.viewClientObjectButtonText == nil)
        #expect(post.coreValue.viewClientObjectButtonText == nil)
        #expect(post.coreValue.viewClientObjectButtonLabels == nil)
    }
}

/// Deprecated APIs (tests are still here to ensure old APIs can still be called)
extension OctopusLocalizedTextTests {
    @available(*, deprecated)
    @Test func ctaWithStringLabelIsAutoTranslated() throws {
        let cta = try OctopusPrefilledPost.CTA(url: URL(string: "myapp://item/42")!, label: "Open")
        #expect(cta.label == "Open")
        #expect(cta.localizedLabel == .autoTranslated("Open"))
    }

    @available(*, deprecated)
    @Test func clientPostWithStringButtonTextIsAutoTranslated() {
        let post = ClientPost(clientObjectId: "object-id", text: "A text long enough",
                              viewClientObjectButtonText: "Discuss")
        #expect(post.viewClientObjectButtonText == "Discuss")
        #expect(post.viewClientObjectButton == .autoTranslated("Discuss"))
        #expect(post.coreValue.viewClientObjectButtonLabels == nil)

        let withoutButton = ClientPost(clientObjectId: "object-id", text: "A text long enough",
                                       viewClientObjectButtonText: nil)
        #expect(withoutButton.viewClientObjectButton == nil)
    }
}
