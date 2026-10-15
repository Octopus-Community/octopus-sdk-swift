//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

/// The Settings tab root, mirroring the Android sample's `SettingsScreen` in order and measure: the Community card
/// (read-only), Account, the SDK group (Appearance, Language, Configuration), Support (Developer tools, Send
/// feedback, About), Reset, then the version line. Rows are full-bleed 56 pt `SettingsSummaryRow`s on the screen
/// ground, their text at x56, 1 pt dividers inset 52, group headers 24 above and 8 below, as on Android.
///
/// Each value has one way in: the Community block carries no "Change" of its own, Configuration is the row that
/// opens the Config screen.
struct SettingsView: View {
    @StateObjectCompat private var viewModel = SettingsViewModel()
    @ObservedObject private var appearance = SampleAppearanceStore.instance
    @State private var showSendFeedback = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                communityBlock
                accountRow
                sdkGroup
                supportGroup
                resetGroup
                versionLine
            }
        }
        .sampleScreenBackground()
        .accessibilityId("settings-screen")
        .sampleTabRoot("Settings")
        .hostAppFooter()
        .sheet(isPresented: $showSendFeedback) { SendFeedbackSheet() }
        .alert("Reset Configuration?", isPresented: $viewModel.isResetConfirmationPresented) {
            Button("Reset", role: .destructive, action: viewModel.confirmReset)
                .accessibilityId("settings-reset-confirm")
            Button("Cancel", role: .cancel) {}
                .accessibilityId("settings-reset-cancel")
        } message: {
            Text(Self.resetMessage)
        }
    }

    // MARK: - Community

    /// What the SDK is pointed at and whether it works, read-only, as the Android "Community" card: 16 at the
    /// sides and above, 8 below.
    private var communityBlock: some View {
        SettingsCard(title: "Community") {
            // "Name", not "Community": the card title already says Community, as on Android.
            SettingsInfoRow(label: "Name", value: viewModel.communityName)
            SettingsInfoRow(label: "Server", value: viewModel.serverName,
                            valueColor: viewModel.sdkConfig?.featureEnv != nil
                                ? SampleTokens.Colors.warningText : SampleTokens.Colors.text)
            SettingsStatusLine(status: viewModel.status)
        }
        .accessibilityId("settings-community-block")
        .padding(.horizontal, SampleTokens.Spacing.space4)
        .padding(.top, SampleTokens.Spacing.space4)
        .padding(.bottom, SampleTokens.Spacing.space2)
    }

    // MARK: - Account

    /// Account sits alone above the first group header: its value changes what every other screen can do.
    private var accountRow: some View {
        NavigationLink(destination: AccountView()) {
            SettingsSummaryRow(systemImage: "person.fill", title: "Account", subtitle: viewModel.accountSubtitle)
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityId("settings-account-row")
    }

    // MARK: - SDK

    @ViewBuilder
    private var sdkGroup: some View {
        SettingsGroupHeader(title: "SDK")
        NavigationLink(destination: AppearanceView()) {
            SettingsSummaryRow(
                systemImage: "moon.fill", title: "Appearance",
                subtitle: "\(appearance.themePreset.title) · \(appearance.appearance.summaryTitle)")
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityId("settings-appearance-row")
        SettingsRowDivider()
        NavigationLink(destination: LanguageSettingsView()) {
            SettingsSummaryRow(systemImage: "globe", title: "Language", subtitle: viewModel.languageSubtitle)
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityId("settings-language-row")
        // The Config screen exists in internal demo mode only (TestFlight builds set it): a public build runs
        // the built-in configuration and has nothing to configure.
        if DefaultValuesProvider.internalDemoMode {
            SettingsRowDivider()
            NavigationLink(destination: ConfigView(isRevisit: true).hostAppFooter()) {
                SettingsSummaryRow(systemImage: "cloud", title: "Configuration",
                                   subtitle: "Community, server, SSO user, theme")
            }
            .buttonStyle(SettingsRowButtonStyle())
            .accessibilityId("settings-reconfigure-button")
        }
    }

    // MARK: - Support

    @ViewBuilder
    private var supportGroup: some View {
        SettingsGroupHeader(title: "Support")
        NavigationLink(destination: DeveloperToolsView()) {
            SettingsSummaryRow(systemImage: "terminal", title: "Developer tools",
                               subtitle: "Host app integration · Events log · Debug info · Debug console")
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityId("settings-devtools-row")
        // Internal builds with a configured repository only, as on Android: the issue carries the log.
        if DefaultValuesProvider.internalDemoMode && !DefaultValuesProvider.feedbackRepo.isEmpty {
            SettingsRowDivider()
            Button(action: { showSendFeedback = true }) {
                SettingsSummaryRow(systemImage: "exclamationmark.bubble", title: "Send feedback",
                                   subtitle: "Pre-filled GitHub issue · internal builds only")
            }
            .buttonStyle(SettingsRowButtonStyle())
            .accessibilityId("settings-feedback-row")
        }
        SettingsRowDivider()
        NavigationLink(destination: AboutView()) {
            SettingsSummaryRow(systemImage: "info.circle", title: "About", subtitle: Self.shortVersions)
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityId("settings-about-row")
    }

    // MARK: - Reset

    @ViewBuilder
    private var resetGroup: some View {
        SettingsGroupHeader(title: "Reset")
        Button(action: viewModel.requestReset) {
            SettingsSummaryRow(systemImage: "trash", title: "Reset Configuration",
                               subtitle: "Local demo setup only — nothing is deleted on the server",
                               destructive: true)
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityId("settings-reset-button")
    }

    /// The version line, centred, 24 above and below, as the Android footer.
    private var versionLine: some View {
        Text(Self.fullVersions)
            .font(SampleTokens.Typography.caption)
            .foregroundColor(SampleTokens.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SampleTokens.Spacing.space4)
            .padding(.vertical, SampleTokens.Spacing.space6)
            .accessibilityId("settings-version-label")
    }

    /// Where the app lands after the reset depends on the build: only internal demo mode has a Config screen.
    private static var resetMessage: String {
        let landing = DefaultValuesProvider.internalDemoMode ? "restarts on the Config screen" : "goes back to Scenarios"
        return "Clears the sample's saved setup — server, community, SSO user, theme — and \(landing). " +
            "Nothing is deleted on the server."
    }

    static var sampleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var sampleBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    static var sampleVersionLine: String { "Sample \(sampleVersion) (\(sampleBuild))" }

    static var shortVersions: String { "Sample \(sampleVersion) · SDK \(OctopusCore.version)" }

    static var fullVersions: String { "Sample \(sampleVersion) (\(sampleBuild)) · SDK \(OctopusCore.version)" }
}

/// A read-only label/value line, the iOS twin of the Android `SampleInfoRow`: label at the start, value at the end.
/// When both no longer fit on one line (a long value, an accessibility text size) the value drops under the label
/// instead of squeezing the label into a mid-word wrap, as the Android row does since its 200 % font fix.
struct SettingsInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = SampleTokens.Colors.text

    var body: some View {
        AdaptiveLabelValue {
            labelText
        } value: {
            valueText
        }
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(label)
            .font(SampleTokens.Typography.callout)
            .foregroundColor(SampleTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueText: some View {
        Text(value)
            .font(SampleTokens.Typography.bodyStrong)
            .foregroundColor(valueColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A label and its value on one line when they fit, the value under the label otherwise. Words are never cut: on
/// iOS 16 and later the row measures itself; on iOS 15 it stacks at the accessibility text sizes.
struct AdaptiveLabelValue<Label: View, Value: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let label: () -> Label
    @ViewBuilder let value: () -> Value

    var body: some View {
        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                inline
                stacked
            }
        } else if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            inline
        }
    }

    private var inline: some View {
        HStack(alignment: .firstTextBaseline, spacing: SampleTokens.Spacing.space3) {
            label().fixedSize()
            Spacer(minLength: SampleTokens.Spacing.space2)
            value().fixedSize().multilineTextAlignment(.trailing)
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            label()
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A list section header with a supporting line under its title, as the Android sample's cards draw them.
struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            Text(title)
            Text(subtitle)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .textCase(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The SDK status, as the Android `StatusDot` and its detail: an 8 pt dot 6 from its label, both in the status
/// colour, the detail line 14 in and 2 below.
private struct SettingsStatusLine: View {
    let status: SampleSDKStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: SampleTokens.Spacing.space2, height: SampleTokens.Spacing.space2)
                    .accessibilityHidden(true)
                Text("SDK · \(status.label)")
                    .font(SampleTokens.Typography.badgeLabel)
                    .foregroundColor(status.color)
                    .accessibilityId("settings-sdk-status")
            }
            Text(status.detail)
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 14)
        }
        .animation(.default, value: status)
    }
}
