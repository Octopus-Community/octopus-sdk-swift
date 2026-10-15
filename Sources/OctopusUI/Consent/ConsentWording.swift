//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// The three legal documents the SDK wordings link to.
struct ConsentLegalUrls: Equatable {
    let terms: URL
    let privacy: URL
    let rules: URL
}

/// The consent wordings a screen displays, once the community's custom texts and the SDK wordings are resolved.
/// Views render it as is: choosing between a custom text and a localization key only happens in
/// ``resolve(mode:texts:contribution:urls:locale:)``.
enum ConsentWording: Equatable {
    /// Implicit mode: the notice under the post, comment and reply composers.
    case implicit(notice: String)
    /// One checkbox per legal document.
    case multiCheckbox(termsLabel: String, privacyLabel: String, rulesLabel: String)
    /// A single checkbox for the terms and the community rules, and the text under it.
    case singleCheckbox(label: String, belowText: String)

    /// Resolves the wordings of `mode`.
    ///
    /// - The community's `texts` only apply when their case is the one of `mode`, which stays the source of truth
    ///   (overridden or not); otherwise every wording is the SDK one.
    /// - Each field falls back on its own: an absent, empty or whitespace-only field gets the SDK wording while the
    ///   others keep their custom text.
    /// - The single-checkbox `belowText` is one text for posts, comments and replies, replacing the three SDK
    ///   privacy acknowledgements.
    static func resolve(mode: TermsAcceptanceMode, texts: ConsentTexts?, contribution: ConsentContribution,
                        urls: ConsentLegalUrls, locale: Locale?) -> ConsentWording {
        switch mode {
        case .implicit:
            var notice: String?
            if case let .implicit(customNotice)? = texts {
                notice = custom(customNotice)
            }
            return .implicit(notice: notice ?? L10n(
                "Content.Create.Legal_termOfUse:%@_privacyPolicy:%@_communityGuidelines:%@", locale: locale,
                urls.terms.absoluteString, urls.privacy.absoluteString, urls.rules.absoluteString))
        case .explicitMultiCheckbox:
            var termsLabel: String?
            var privacyLabel: String?
            var rulesLabel: String?
            if case let .multiCheckbox(customTerms, customPrivacy, customRules)? = texts {
                termsLabel = custom(customTerms)
                privacyLabel = custom(customPrivacy)
                rulesLabel = custom(customRules)
            }
            return .multiCheckbox(
                termsLabel: termsLabel
                    ?? L10n("Consent.Accept.Terms", locale: locale, urls.terms.absoluteString),
                privacyLabel: privacyLabel
                    ?? L10n("Consent.Accept.Privacy", locale: locale, urls.privacy.absoluteString),
                rulesLabel: rulesLabel
                    ?? L10n("Consent.Accept.Rules", locale: locale, urls.rules.absoluteString))
        case .explicitSingleCheckbox:
            var label: String?
            var belowText: String?
            if case let .singleCheckbox(customLabel, customBelowText)? = texts {
                label = custom(customLabel)
                belowText = custom(customBelowText)
            }
            return .singleCheckbox(
                label: label ?? L10n("Consent.Accept.TermsRules", locale: locale,
                                     urls.terms.absoluteString, urls.rules.absoluteString),
                belowText: belowText
                    ?? L10n(contribution.privacyAckKey, locale: locale, urls.privacy.absoluteString))
        }
    }

    /// The notice under the post, comment and reply composers, which only show it in the implicit mode: the
    /// community's own when it set one, the SDK wording otherwise. It is the same text for every contribution.
    static func implicitNotice(texts: ConsentTexts?, urls: ConsentLegalUrls, locale: Locale?) -> String {
        resolve(mode: .implicit, texts: texts, contribution: .post, urls: urls, locale: locale).implicitNotice ?? ""
    }

    /// The notice of the implicit mode, `nil` for the explicit ones.
    var implicitNotice: String? {
        guard case let .implicit(notice) = self else { return nil }
        return notice
    }

    /// A custom text as written, or `nil` when it is absent, empty or only whitespace. Checked here too because
    /// the debug override hands texts over without going through the config mapper. Only the line separators are
    /// touched: a text written in a dashboard can carry `\r\n` or a lone `\r`, which would not break a markdown
    /// line the way `\n` does, so they all become `\n`.
    private static func custom(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }
}
