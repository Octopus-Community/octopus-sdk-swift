//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// "Live community config": what the SDK runs with for the current community, as on Android. The iOS SDK exposes
/// no read of the backend config, so a field the scenarios did not override reads "backend value" instead of
/// Android's resolved flag ("pictures ✗ off · polls ✗ off").
struct LiveCommunityConfigCard: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance
    @ObservedObject private var provider = OctopusSDKProvider.instance
    @ObservedObject private var unifiedProfile = UnifiedProfileManager.instance
    @ObservedObject private var toggles = FeatureToggles.instance

    static let backendValue = "backend value"
    static let notExposed = "—"

    /// Android `CommunityConfigPreview`: a tinted surface with a 1 border and a 12 radius, padding 12, and every line
    /// 4 apart, so the rows sit at Android's pitch.
    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            Text("Live community config")
                .font(Font.subheadline.weight(.bold))
                .foregroundColor(SampleTokens.Colors.text)
            Text("What the SDK sees for the current community (its key + any local override applied below). " +
                 "The iOS SDK exposes no read of the backend config, so a field with no override reads " +
                 "\"\(Self.backendValue)\". Updates after switchCommunity.")
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(rows, id: \.label) { row in
                ConfigRow(label: row.label, value: row.value)
            }
        }
        .padding(SampleTokens.Spacing.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(SampleTokens.Colors.accentTint))
        .overlay(shape.strokeBorder(SampleTokens.Colors.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityId("community-config-preview")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
    }

    private var rows: [(label: String, value: String)] {
        let options = overrides.contentOptions
        return [
            ("API key", ScenarioCatalog.maskApiKey(provider.currentApiKey)),
            ("Post", options.map {
                "pictures \(OverrideLabels.tick($0.post.enablePictures)) · " +
                    "polls \(OverrideLabels.tick($0.post.enablePolls)) · " +
                    "text required \(OverrideLabels.tick($0.post.textRequired))"
            } ?? Self.backendValue),
            ("Comment", options.map { "pictures \(OverrideLabels.tick($0.comment.enablePictures))" }
                ?? Self.backendValue),
            ("Reply", options.map { "pictures \(OverrideLabels.tick($0.reply.enablePictures))" } ?? Self.backendValue),
            ("Profile lock", overrides.profileFieldsLock.map(OverrideLabels.lockLine) ?? Self.backendValue),
            ("Unified Profile (exposeClientUserId)",
             unifiedProfile.state.exposeClientUserIdOverride.map(OverrideLabels.tick) ?? Self.backendValue),
            ("Terms acceptance", overrides.termsAcceptance.map(OverrideLabels.termsLine) ?? Self.backendValue),
            ("Force nickname choice", overrides.forceNicknameChoice.map(OverrideLabels.tick) ?? Self.backendValue),
            ("Consent texts", overrides.consentTexts.map { ConsentTextsPresets.describe($0) } ?? Self.backendValue),
            ("Gamification", Self.notExposed),
            ("Force login (strong actions)", OverrideLabels.tick(toggles.forceLoginEnabled)),
            ("Display account age", Self.notExposed),
            ("Powered by Octopus", Self.notExposed),
        ]
    }
}

/// Android's `Line`: label and value on one row, the value trailing, as long as they fit; the value goes under the
/// label otherwise, so a long value never squeezes the label into a word-per-line column.
private struct ConfigRow: View {
    let label: String
    let value: String

    var body: some View {
        AdaptiveLabelValue {
            Text(label)
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.text)
                .fixedSize(horizontal: false, vertical: true)
        } value: {
            Text(value)
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
