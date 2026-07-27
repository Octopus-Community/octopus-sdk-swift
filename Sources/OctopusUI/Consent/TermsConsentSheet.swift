//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// The contribution the user is trying to make, driving the consent sheet's button label and the
/// single-checkbox mode's passive privacy acknowledgement wording.
enum ConsentContribution {
    case post
    case comment
    case reply

    var buttonKey: String {
        switch self {
        case .post: return "Consent.Button.Post"
        case .comment: return "Consent.Button.Comment"
        case .reply: return "Consent.Button.Reply"
        }
    }

    /// Passive privacy-policy acknowledgement shown under the single combined checkbox (mode 3).
    var privacyAckKey: String {
        switch self {
        case .post: return "Consent.Ack.Privacy.Post"
        case .comment: return "Consent.Ack.Privacy.Comment"
        case .reply: return "Consent.Ack.Privacy.Reply"
        }
    }
}

/// Explicit terms-acceptance bottom sheet shown at the user's first contribution when the community
/// runs an explicit consent mode. Its content differs by ``TermsAcceptanceMode`` (one checkbox per
/// document vs a single combined checkbox + passive privacy acknowledgement); the behaviour (trigger,
/// dismissal, memorization) is identical. The action button is disabled until the required box(es)
/// are checked; tapping it calls ``onAccept`` (which records acceptance and publishes).
struct TermsConsentSheet: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager

    /// One of the explicit modes (`.implicit` renders nothing — the caller only presents this for
    /// explicit modes).
    let mode: TermsAcceptanceMode
    let contribution: ConsentContribution
    let termsUrl: URL
    let privacyUrl: URL
    let rulesUrl: URL
    /// Called when the user taps the (enabled) action button. The caller records acceptance and
    /// resumes publishing, and dismisses the sheet.
    let onAccept: () -> Void

    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false
    @State private var acceptedRules = false
    @State private var acceptedCombined = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: L10n("Consent.Title", locale: locale))
                .font(theme.fonts.body1.weight(.semibold))
                .foregroundColor(theme.colors.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 36)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 4) {
                switch mode {
                case .explicitMultiCheckbox:
                    checkboxRow(isChecked: acceptedTerms,
                                markdown: L10n("Consent.Accept.Terms", locale: locale, termsUrl.absoluteString)) {
                        acceptedTerms.toggle()
                    }
                    checkboxRow(isChecked: acceptedPrivacy,
                                markdown: L10n("Consent.Accept.Privacy", locale: locale, privacyUrl.absoluteString)) {
                        acceptedPrivacy.toggle()
                    }
                    checkboxRow(isChecked: acceptedRules,
                                markdown: L10n("Consent.Accept.Rules", locale: locale, rulesUrl.absoluteString)) {
                        acceptedRules.toggle()
                    }
                case .explicitSingleCheckbox:
                    checkboxRow(isChecked: acceptedCombined,
                                markdown: L10n("Consent.Accept.TermsRules", locale: locale,
                                               termsUrl.absoluteString, rulesUrl.absoluteString)) {
                        acceptedCombined.toggle()
                    }
                    RichText(L10n(contribution.privacyAckKey, locale: locale, privacyUrl.absoluteString))
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray900)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                case .implicit:
                    EmptyView()
                }
            }

            Button(action: { if isValid { onAccept() } }) {
                Text(verbatim: L10n(contribution.buttonKey, locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OctopusButtonStyle(.main, enabled: isValid))
            .disabled(!isValid)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .padding(.horizontal, 28)
        }
    }

    /// Whether the required checkbox(es) for the current mode are all checked.
    private var isValid: Bool {
        switch mode {
        case .explicitMultiCheckbox: return acceptedTerms && acceptedPrivacy && acceptedRules
        case .explicitSingleCheckbox: return acceptedCombined
        case .implicit: return true
        }
    }

    private var locale: Locale? { languageManager.overridenLocale }

    /// A checkbox row: tapping a link opens its legal URL (handled by `RichText`); tapping anywhere
    /// else on the row toggles the checkbox.
    /// Squared, rounded-corner checkbox (design system) — filled with the primary color + a white
    /// checkmark when checked, an outlined box when not. Themeable via `primary` / `onPrimary`.
    @ViewBuilder
    private func consentCheckbox(isChecked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isChecked ? theme.colors.primary : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isChecked ? theme.colors.primary : theme.colors.gray300, lineWidth: 2))
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.colors.onPrimary)
                    .opacity(isChecked ? 1 : 0))
            .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private func checkboxRow(isChecked: Bool, markdown: String, toggle: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 16) {
            consentCheckbox(isChecked: isChecked)
            RichText(markdown)
                .font(theme.fonts.body2)
                .foregroundColor(theme.colors.gray900)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .accessibilityAddTraits(.isButton)
        .accessibilityValueInBundle(isChecked ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected")
    }
}
