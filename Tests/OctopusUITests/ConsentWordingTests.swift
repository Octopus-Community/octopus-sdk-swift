//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusCore
@testable import OctopusUI

/// Every mode, and one fully filled set of texts per mode (file scope so `@Test(arguments:)` can use them).
private let allModes: [TermsAcceptanceMode] = [.implicit, .explicitMultiCheckbox, .explicitSingleCheckbox]
private let fullTexts: [ConsentTexts] = [
    .implicit(notice: "Custom notice"),
    .multiCheckbox(termsLabel: "Custom terms", privacyLabel: "Custom privacy", rulesLabel: "Custom rules"),
    .singleCheckbox(label: "Custom label", belowText: "Custom below"),
]

/// Truth table of the consent wordings: mode × community texts × contribution.
struct ConsentWordingTests {
    private static let urls = ConsentLegalUrls(terms: URL(string: "https://example.com/terms")!,
                                               privacy: URL(string: "https://example.com/privacy")!,
                                               rules: URL(string: "https://example.com/rules")!)
    private static let locale = Locale(identifier: "en")
    private static let contributions: [ConsentContribution] = [.post, .comment, .reply]

    private func resolve(_ mode: TermsAcceptanceMode, _ texts: ConsentTexts?,
                         _ contribution: ConsentContribution = .post) -> ConsentWording {
        ConsentWording.resolve(mode: mode, texts: texts, contribution: contribution, urls: Self.urls,
                               locale: Self.locale)
    }

    private func isCase(of texts: ConsentTexts, for mode: TermsAcceptanceMode) -> Bool {
        switch (texts, mode) {
        case (.implicit, .implicit), (.multiCheckbox, .explicitMultiCheckbox),
             (.singleCheckbox, .explicitSingleCheckbox):
            return true
        default:
            return false
        }
    }

    // MARK: SDK wordings (no texts): the keys the views used to pick

    @Test func sdkImplicitNotice() {
        for contribution in Self.contributions {
            #expect(resolve(.implicit, nil, contribution) == .implicit(notice:
                "By posting my message, I accept the [Terms of Use](https://example.com/terms), " +
                "[Privacy Policy](https://example.com/privacy), and " +
                "[Community Guidelines](https://example.com/rules)"))
        }
    }

    @Test func sdkMultiCheckboxLabels() {
        #expect(resolve(.explicitMultiCheckbox, nil) == .multiCheckbox(
            termsLabel: "I accept the [Terms of Use](https://example.com/terms)",
            privacyLabel: "I accept the [Privacy Policy](https://example.com/privacy)",
            rulesLabel: "I accept the [Community Guidelines](https://example.com/rules)"))
    }

    @Test func sdkSingleCheckboxWordingsFollowTheContribution() {
        let label = "I accept the [Terms of Use](https://example.com/terms) and the " +
            "[Community Guidelines](https://example.com/rules)"
        #expect(resolve(.explicitSingleCheckbox, nil, .post) == .singleCheckbox(label: label, belowText:
            "By posting, I acknowledge that I have read the [Privacy Policy](https://example.com/privacy)."))
        #expect(resolve(.explicitSingleCheckbox, nil, .comment) == .singleCheckbox(label: label, belowText:
            "By commenting, I acknowledge that I have read the [Privacy Policy](https://example.com/privacy)."))
        #expect(resolve(.explicitSingleCheckbox, nil, .reply) == .singleCheckbox(label: label, belowText:
            "By replying, I acknowledge that I have read the [Privacy Policy](https://example.com/privacy)."))
    }

    // MARK: Rule 1 — texts only apply when their case is the current mode

    @Test(arguments: fullTexts, allModes)
    func textsOfAnotherModeAreIgnored(texts: ConsentTexts, mode: TermsAcceptanceMode) {
        guard !isCase(of: texts, for: mode) else { return }
        for contribution in Self.contributions {
            #expect(resolve(mode, texts, contribution) == resolve(mode, nil, contribution))
        }
    }

    // MARK: Rules 2 & 3 — matching texts, field by field

    @Test func implicitNoticeReplacesTheSdkNoticeForEveryContribution() {
        for contribution in Self.contributions {
            #expect(resolve(.implicit, .implicit(notice: "Custom notice"), contribution)
                    == .implicit(notice: "Custom notice"))
        }
    }

    @Test func multiCheckboxLabelsReplaceTheSdkLabels() {
        #expect(resolve(.explicitMultiCheckbox, fullTexts[1])
                == .multiCheckbox(termsLabel: "Custom terms", privacyLabel: "Custom privacy",
                                  rulesLabel: "Custom rules"))
    }

    @Test func multiCheckboxFallsBackFieldByField() {
        guard case let .multiCheckbox(sdkTerms, sdkPrivacy, sdkRules) = resolve(.explicitMultiCheckbox, nil) else {
            Issue.record("expected the multi-checkbox wording")
            return
        }
        #expect(resolve(.explicitMultiCheckbox,
                        .multiCheckbox(termsLabel: "Custom terms", privacyLabel: nil, rulesLabel: "   "))
                == .multiCheckbox(termsLabel: "Custom terms", privacyLabel: sdkPrivacy, rulesLabel: sdkRules))
        #expect(resolve(.explicitMultiCheckbox,
                        .multiCheckbox(termsLabel: "", privacyLabel: "Custom privacy", rulesLabel: nil))
                == .multiCheckbox(termsLabel: sdkTerms, privacyLabel: "Custom privacy", rulesLabel: sdkRules))
    }

    @Test func singleCheckboxBelowTextIsOneTextForEveryContribution() {
        for contribution in Self.contributions {
            #expect(resolve(.explicitSingleCheckbox, fullTexts[2], contribution)
                    == .singleCheckbox(label: "Custom label", belowText: "Custom below"))
        }
    }

    @Test func singleCheckboxWithoutBelowTextKeepsTheContributionVariants() {
        for contribution in Self.contributions {
            guard case let .singleCheckbox(_, sdkBelowText) = resolve(.explicitSingleCheckbox, nil, contribution)
            else {
                Issue.record("expected the single-checkbox wording")
                return
            }
            #expect(resolve(.explicitSingleCheckbox, .singleCheckbox(label: "Custom label", belowText: nil),
                            contribution)
                    == .singleCheckbox(label: "Custom label", belowText: sdkBelowText))
        }
    }

    @Test func singleCheckboxWithoutLabelKeepsTheSdkLabel() {
        guard case let .singleCheckbox(sdkLabel, _) = resolve(.explicitSingleCheckbox, nil) else {
            Issue.record("expected the single-checkbox wording")
            return
        }
        #expect(resolve(.explicitSingleCheckbox, .singleCheckbox(label: " \n", belowText: "Custom below"))
                == .singleCheckbox(label: sdkLabel, belowText: "Custom below"))
    }

    @Test(arguments: ["", " ", "\n\t "])
    func blankImplicitNoticeKeepsTheSdkNotice(blank: String) {
        #expect(resolve(.implicit, .implicit(notice: blank)) == resolve(.implicit, nil))
    }

    @Test func customTextIsRenderedAsWritten() {
        let notice = "**Read this**\n\nThen [that](https://example.com/that), *please*."
        #expect(resolve(.implicit, .implicit(notice: notice)) == .implicit(notice: notice))
    }

    @Test func customTextIsNeverTreatedAsAFormat() {
        // The SDK wordings are format strings, the custom ones are not: `%@` and a bare `%` stay as written.
        let notice = "Accept %@ and 100 % of the rules"
        #expect(resolve(.implicit, .implicit(notice: notice)) == .implicit(notice: notice))
        #expect(resolve(.explicitMultiCheckbox,
                        .multiCheckbox(termsLabel: notice, privacyLabel: "%@", rulesLabel: "100 %"))
                == .multiCheckbox(termsLabel: notice, privacyLabel: "%@", rulesLabel: "100 %"))
        #expect(resolve(.explicitSingleCheckbox, .singleCheckbox(label: notice, belowText: "100 % %@"))
                == .singleCheckbox(label: notice, belowText: "100 % %@"))
    }

    // MARK: Line separators of custom texts

    @Test func customTextLineSeparatorsAreNormalisedToNewline() {
        // Dashboard texts can carry Windows or old-Mac line endings, which would not break the markdown lines.
        #expect(resolve(.implicit, .implicit(notice: "One\r\nTwo\rThree\nFour"))
                == .implicit(notice: "One\nTwo\nThree\nFour"))
        #expect(resolve(.explicitMultiCheckbox,
                        .multiCheckbox(termsLabel: "A\r\nB", privacyLabel: "C\rD", rulesLabel: "E\nF"))
                == .multiCheckbox(termsLabel: "A\nB", privacyLabel: "C\nD", rulesLabel: "E\nF"))
        #expect(resolve(.explicitSingleCheckbox, .singleCheckbox(label: "A\r\nB", belowText: "C\rD"))
                == .singleCheckbox(label: "A\nB", belowText: "C\nD"))
    }

    // MARK: Accessors

    @Test func implicitNoticeHelperResolvesTheImplicitModeWithoutOptional() {
        func notice(_ texts: ConsentTexts?) -> String {
            ConsentWording.implicitNotice(texts: texts, urls: Self.urls, locale: Self.locale)
        }
        #expect(notice(.implicit(notice: "Custom notice")) == "Custom notice")
        // Texts of another mode, or none, give the SDK notice.
        #expect(resolve(.implicit, nil) == .implicit(notice: notice(nil)))
        #expect(notice(fullTexts[2]) == notice(nil))
        #expect(notice(.implicit(notice: " ")) == notice(nil))
        #expect(!notice(nil).isEmpty)
    }

    @Test func implicitNoticeIsOnlyThereInTheImplicitMode() {
        #expect(resolve(.implicit, nil).implicitNotice != nil)
        #expect(resolve(.explicitMultiCheckbox, nil).implicitNotice == nil)
        #expect(resolve(.explicitSingleCheckbox, nil).implicitNotice == nil)
    }
}
