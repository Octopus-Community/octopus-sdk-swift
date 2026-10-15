//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

// The Settings side's twins of the Android sample's DS list pieces (`SummaryRow`, `SummaryGroupHeader`,
// `SampleCard`, `SampleListGroup`, `SampleSwitchRow`): full-bleed rows on the screen ground instead of the
// system inset-grouped cards, so Settings and its sub-screens measure as Android does, dp for pt.

/// The DS SettingsRow with a chevron: a bare 24 pt icon in `textSecondary`, 16 to the text (which starts at
/// x56), the title over its current value 2 pt apart, a chevron, 56 pt minimum. `destructive` turns the icon
/// and the title `danger`.
struct SettingsSummaryRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var destructive = false

    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space4) {
            Image(systemName: systemImage)
                .font(.system(size: 20))
                .foregroundColor(tint)
                .frame(width: SampleTokens.Size.icon, height: SampleTokens.Size.icon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SampleTokens.Typography.body)
                    .foregroundColor(destructive ? SampleTokens.Colors.danger : SampleTokens.Colors.text)
                Text(subtitle)
                    .font(SampleTokens.Typography.callout)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .frame(width: SampleTokens.Size.icon, height: SampleTokens.Size.icon)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SampleTokens.Spacing.space4)
        .padding(.vertical, SampleTokens.Spacing.space2)
        .frame(maxWidth: .infinity, minHeight: SampleTokens.Size.rowMin, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var tint: Color { destructive ? SampleTokens.Colors.danger : SampleTokens.Colors.textSecondary }
}

/// The pressed state of a full-bleed row: the `surface2` wash Android's ripple leaves, no system highlight.
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? SampleTokens.Colors.surface2 : Color.clear)
    }
}

/// The DS SectionHeader: title in `text`, 24 above, 8 below, 16 at both sides, no divider. An optional count
/// rides as a `surface3` pill with an `outline` edge; `countLabel` is what VoiceOver reads for it ("4 of 5 on").
struct SettingsGroupHeader: View {
    let title: String
    var countText: String?
    var countLabel: String?

    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space2) {
            Text(title)
                .font(SampleTokens.Typography.label)
                .foregroundColor(SampleTokens.Colors.text)
                .accessibilityAddTraits(.isHeader)
            if let countText {
                Text(countText)
                    .font(SampleTokens.Typography.badgeLabel)
                    .foregroundColor(SampleTokens.Colors.text)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .frame(minWidth: SampleTokens.Size.icon)
                    .background(Capsule().fill(SampleTokens.Colors.surface3))
                    .overlay(Capsule().strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
                    .accessibilityLabel(countLabel ?? countText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SampleTokens.Spacing.space4)
        .padding(.top, SampleTokens.Spacing.space6)
        .padding(.bottom, SampleTokens.Spacing.space2)
    }
}

/// The 1 pt divider between Settings rows, inset 52 at the start as on Android, so it starts under the text.
struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(SampleTokens.Colors.hairline)
            .frame(height: 1)
            .padding(.leading, 52)
            .accessibilityHidden(true)
    }
}

/// The DS card (Android `SampleCard`): `surface`, the 8 pt radius and its hairline, 16 inside, 12 between the
/// title block and the content.
struct SettingsCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            if let title {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(SampleTokens.Typography.label)
                        .foregroundColor(SampleTokens.Colors.text)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(SampleTokens.Typography.callout)
                            .foregroundColor(SampleTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SampleTokens.Spacing.space4)
        .sampleCardSurface(cornerRadius: SampleTokens.Radius.medium)
        .accessibilityElement(children: .contain)
    }
}

/// The DS ListGroup: rows on `surface`, clipped to the 8 pt radius; put `SettingsListDivider` between them.
struct SettingsListGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(maxWidth: .infinity)
            .background(SampleTokens.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous))
    }
}

/// The separator of a `SettingsListGroup`: hairline, inset 16 at both sides.
struct SettingsListDivider: View {
    var body: some View {
        Rectangle()
            .fill(SampleTokens.Colors.hairline)
            .frame(height: 1)
            .padding(.horizontal, SampleTokens.Spacing.space4)
            .accessibilityHidden(true)
    }
}

/// The radio of a selectable row, a pure indicator: the row owns the tap and the selected trait.
struct SettingsRadioIndicator: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 20))
            .foregroundColor(isSelected ? SampleTokens.Colors.accentText : SampleTokens.Colors.textSecondary)
            .frame(width: SampleTokens.Size.icon, height: SampleTokens.Size.icon)
            .accessibilityHidden(true)
    }
}

/// The supporting line under a Settings sub-screen (Android `bodySmall` in `onSurfaceVariant`).
struct SettingsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(SampleTokens.Typography.caption)
            .foregroundColor(SampleTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
