//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// One preset of the consent texts scenario: the texts to apply and the terms-acceptance mode they need.
struct ConsentTextsPreset {
    let testId: String
    let label: String
    let mode: TermsAcceptanceMode
    let texts: ConsentTexts
}

/// The consent texts scenario's presets, with the same ids, order, labels and texts as the Android sample: the QA
/// pipeline drives both platforms from the shared QA catalog. Every brand and URL is fictional, because the
/// sample ships in the public repository.
enum ConsentTextsPresets {
    static let clearTestId = "qa-preset-consentTexts-clear"

    static let all: [ConsentTextsPreset] = [
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-1",
            label: "Implicit — short notice with a link",
            mode: .implicit,
            texts: .implicit(notice: shortNotice)),
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-2",
            label: "Multi checkbox — short labels with links",
            mode: .explicitMultiCheckbox,
            texts: .multiCheckbox(
                termsLabel: "I accept the **club terms** ([read them](https://example.com/terms))",
                privacyLabel: "I accept the [privacy notice](https://example.com/privacy)",
                rulesLabel: "I will follow the [*trail etiquette*](https://example.com/etiquette)")),
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-3",
            label: "Single checkbox — short label and text below",
            mode: .explicitSingleCheckbox,
            texts: .singleCheckbox(
                label: "I accept the [club terms](https://example.com/terms) and the " +
                    "[trail etiquette](https://example.com/etiquette)",
                belowText: "Your data is handled as described in our " +
                    "[privacy notice](https://example.com/privacy).")),
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-4",
            label: "Implicit — long notice (scrolls past 5 lines)",
            mode: .implicit,
            texts: .implicit(notice: longNotice)),
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-5",
            label: "Multi checkbox — long labels, several links",
            mode: .explicitMultiCheckbox,
            texts: .multiCheckbox(
                termsLabel: "I have read and accept the **Pinecone Run Club membership terms**, including the " +
                    "[event rules](https://example.com/events) and the " +
                    "[refund policy](https://example.com/refunds).\n" +
                    "Membership renews every season.",
                privacyLabel: "I accept the [privacy notice](https://example.com/privacy). *Race results are public* " +
                    "and stay on the club's leaderboard after I leave.",
                rulesLabel: "I will follow the [trail etiquette](https://example.com/etiquette): give way uphill, " +
                    "keep dogs on a leash, and take my litter home.\n\nRepeated breaches end a membership.")),
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-6",
            label: "Single checkbox — long, multi-paragraph",
            mode: .explicitSingleCheckbox,
            texts: .singleCheckbox(
                label: "I accept the **Pinecone Run Club membership terms** ([read them](https://example.com/terms)) " +
                    "and the [trail etiquette](https://example.com/etiquette).",
                belowText: "We use your posts, photos and race results to run the club.\n\n" +
                    "They stay visible to members until you delete them. Read the " +
                    "[privacy notice](https://example.com/privacy) to export or erase your data, or write " +
                    "to the volunteers through the [contact page](https://example.com/contact).\n\n" +
                    "# This heading stays plain text\n- and so does this list item")),
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-7",
            label: "Single checkbox — empty fields (SDK wordings)",
            mode: .explicitSingleCheckbox,
            texts: .singleCheckbox(label: "", belowText: "   ")),
        ConsentTextsPreset(
            testId: "qa-preset-consentTexts-8",
            label: "Multi checkbox with implicit texts (SDK wordings)",
            mode: .explicitMultiCheckbox,
            texts: .implicit(notice: shortNotice)),
    ]

    private static let shortNotice =
        "By posting, you agree to the [Pinecone Run Club charter](https://example.com/charter)."

    private static let longNotice =
        "By posting, you agree to the [Pinecone Run Club charter](https://example.com/charter) and to our " +
        "[event rules](https://example.com/events).\n\n" +
        "**Be kind on the trail.** Members who post race results, photos or routes keep the rights to " +
        "them and let the club show them in the app.\n\n" +
        "*Your data:* we keep your posts for as long as your account exists. Read the " +
        "[privacy notice](https://example.com/privacy) to learn how to export or delete them.\n\n" +
        "Questions? Write to the volunteers through the [contact page](https://example.com/contact)."

    /// The mode, worded as the Android sample's result line.
    static func modeLabel(_ mode: TermsAcceptanceMode) -> String {
        switch mode {
        case .implicit: "implicit"
        case .explicitMultiCheckbox: "multi checkbox"
        case .explicitSingleCheckbox: "single checkbox"
        }
    }

    /// The texts, worded as the Android sample's result line.
    static func describe(_ texts: ConsentTexts?) -> String {
        switch texts {
        case nil:
            return "no texts (SDK wordings)"
        case let .implicit(notice)?:
            return "implicit texts · notice \(filled(notice))"
        case let .multiCheckbox(termsLabel, privacyLabel, rulesLabel)?:
            let setCount = [termsLabel, privacyLabel, rulesLabel].filter { filled($0) == "set" }.count
            return "multi checkbox texts · \(setCount)/3 labels set"
        case let .singleCheckbox(label, belowText)?:
            return "single checkbox texts · label \(filled(label)), text below \(filled(belowText))"
        }
    }

    private static func filled(_ text: String?) -> String {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "empty" }
        return "set"
    }
}
