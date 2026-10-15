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
///
/// The wordings come from ``ConsentWording``: the community's texts when it set some for this mode, the SDK ones
/// otherwise. The title, the checkboxes and the text under the checkbox scroll together; only the button stays
/// pinned at the bottom, so a long text never pushes it off screen.
struct TermsConsentSheet: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var languageManager: LanguageManager

    /// One of the explicit modes (`.implicit` renders nothing — the caller only presents this for
    /// explicit modes).
    let mode: TermsAcceptanceMode
    /// The community's custom wordings, `nil` for the SDK ones.
    let consentTexts: ConsentTexts?
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
    /// Natural height of everything above the button.
    @State private var scrollContentHeight: CGFloat = 0
    /// Height of the pinned button, paddings included.
    @State private var buttonAreaHeight: CGFloat = 0
    /// Height of the window hosting the sheet, `0` until it is known.
    @State private var windowHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            scrollArea
            actionButton
                // Measure and keep the ideal height: a compressible button would be squeezed by the stack when the
                // scroll area is oversized, and the squeezed height would then be fed back into the scroll area's cap.
                .fixedSize(horizontal: false, vertical: true)
                .readHeight($buttonAreaHeight)
        }
        .readWindowHeight($windowHeight)
    }

    /// When the sheet is sized to its content, the scroll area is as tall as that content up to the cap, then
    /// scrolls. Otherwise (before iOS 16.4, or with VoiceOver) the sheet is full height and the scroll area takes
    /// the room the button leaves. A regular-width sheet (iPad, wide Split View) is a form sheet, and a sheet in a
    /// compact-height window (iPhone in landscape) is presented full screen: in both the detents are ignored and the
    /// sheet's height has nothing to do with the content's, so they take the second branch too.
    @ViewBuilder
    private var scrollArea: some View {
        if SizedSheetModifier.sizesToContent && horizontalSizeClass != .regular && verticalSizeClass != .compact {
            // No extremity anchors: Compat.ScrollView would wrap the content in a VStack with two 1pt spacers that
            // the measured height does not include, so the content would be 2pt taller than the frame and scroll.
            Compat.ScrollView(canScrollToExtremities: false) {
                scrollableContent
                    .readHeight($scrollContentHeight)
            }
            .frame(height: Self.scrollAreaHeight(contentHeight: scrollContentHeight,
                                                 buttonAreaHeight: buttonAreaHeight,
                                                 windowHeight: windowHeight,
                                                 fallbackWindowHeight: provisionalWindowHeight))
        } else {
            Compat.ScrollView(canScrollToExtremities: false) {
                scrollableContent
            }
        }
    }

    private var scrollableContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: L10n("Consent.Title", locale: locale))
                .font(theme.fonts.body1.weight(.semibold))
                .foregroundColor(theme.colors.gray900)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 36)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 4) {
                switch wording {
                case let .multiCheckbox(termsLabel, privacyLabel, rulesLabel):
                    checkboxRow(isChecked: acceptedTerms, markdown: termsLabel) {
                        acceptedTerms.toggle()
                    }
                    checkboxRow(isChecked: acceptedPrivacy, markdown: privacyLabel) {
                        acceptedPrivacy.toggle()
                    }
                    checkboxRow(isChecked: acceptedRules, markdown: rulesLabel) {
                        acceptedRules.toggle()
                    }
                case let .singleCheckbox(label, belowText):
                    checkboxRow(isChecked: acceptedCombined, markdown: label) {
                        acceptedCombined.toggle()
                    }
                    belowCheckboxText(belowText)
                case .implicit:
                    EmptyView()
                }
            }
        }
    }

    private var actionButton: some View {
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

    private var wording: ConsentWording {
        ConsentWording.resolve(mode: mode, texts: consentTexts, contribution: contribution,
                               urls: ConsentLegalUrls(terms: termsUrl, privacy: privacyUrl, rules: rulesUrl),
                               locale: locale)
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

    /// A checkbox row: tapping a link opens its URL (handled by `RichText`); tapping anywhere
    /// else on the row toggles the checkbox.
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

    /// The passive text under the single checkbox (not tappable as a whole; its links open).
    private func belowCheckboxText(_ markdown: String) -> some View {
        RichText(markdown)
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
    }
}

extension TermsConsentSheet {
    /// Share of the window height the sheet can take before its content scrolls, the same as ``ContentSizedSheet``.
    static let maxHeightRatio = ContentSizedSheetLayout.maxHeightRatio

    /// Height of the scroll area of a sheet sized to its content: the content's natural height, capped so that the
    /// scroll area and the pinned button together stay within ``maxHeightRatio`` of the window. While the window
    /// height is unknown (zero), `fallbackWindowHeight` stands in for it, so the first pass never asks the system for
    /// an uncapped detent.
    static func scrollAreaHeight(contentHeight: CGFloat, buttonAreaHeight: CGFloat, windowHeight: CGFloat,
                                 fallbackWindowHeight: CGFloat) -> CGFloat {
        let window = resolvedWindowHeight(measured: windowHeight, fallback: fallbackWindowHeight)
        guard window > 0 else { return contentHeight }
        return min(contentHeight, max(0, window * maxHeightRatio - buttonAreaHeight))
    }
}
