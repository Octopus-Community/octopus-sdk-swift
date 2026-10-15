//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

/// Developer tools › Debug info, the iOS twin of the Android `DebugInfoScreen`: what a bug report needs, read
/// only. The SDK state, the feature toggles, the configuration, the host app wiring and the build, each in its
/// card. Nothing here changes a setting; Settings › Configuration (internal builds) and Developer tools do.
struct DebugInfoView: View {
    @StateObjectCompat private var settings = SettingsViewModel()
    @ObservedObject private var live = ScenarioLiveState.instance
    @ObservedObject private var toggles = FeatureToggles.instance
    @ObservedObject private var appearance = SampleAppearanceStore.instance
    @ObservedObject private var hostStore = HostIntegrationStore.instance
    @ObservedObject private var clientProfile = ClientProfileManager.instance
    @ObservedObject private var network = SampleNetworkMonitor.instance
    @ObservedObject private var userManager = AppUserManager.instance

    /// "Debug" or "Release", the Xcode build configuration this binary was compiled with.
    static var buildConfiguration: String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }

    var body: some View {
        let config = DebugInfoSummary.shownConfig(saved: settings.sdkConfig,
                                                  internalDemoMode: DefaultValuesProvider.internalDemoMode)
        let status = settings.status
        ScrollView {
            VStack(spacing: SampleTokens.Spacing.space3) {
                DebugInfoCard(title: "SDK") {
                    SettingsInfoRow(label: "SDK version", value: OctopusCore.version)
                    // The verdict of the Settings Community block, so this screen and Settings never disagree.
                    SettingsInfoRow(label: "Status", value: status.label, valueColor: status.color)
                        .accessibilityId("debug-info-sdk-status")
                    SettingsInfoRow(label: "Network", value: SampleNetworkMonitor.label(
                        isOnline: network.isOnline, isForcedOffline: SampleDebugSettings.forceOffline))
                    SettingsInfoRow(label: "Initialized", value: OctopusSDKProvider.isCreated ? "true" : "false")
                    SettingsInfoRow(label: "Auth mode",
                                    value: config.map { DebugInfoSummary.authShortLabel($0.authKind) } ?? "—")
                    SettingsInfoRow(label: "Connection", value: DebugInfoSummary.connection(
                        profile: live.profile, nickname: userManager.appUser?.nickname))
                        .accessibilityId("debug-info-connection")
                    SettingsInfoRow(label: "Unread notifications", value: "\(live.notSeenNotificationsCount)")
                    SettingsInfoRow(label: "Community access",
                                    value: live.hasAccessToCommunity ? "Granted" : "Denied")
                }

                DebugInfoCard(title: "Feature toggles",
                              subtitle: "Set on Scenarios. A bug report that omits these is a bug report twice.") {
                    ForEach(FeatureToggle.allCases) { toggle in
                        SettingsInfoRow(label: toggle.label,
                                        value: toggle.readOnlyValueLine(enabled: toggles.isEnabled(toggle)))
                    }
                }

                DebugInfoCard(title: "Configuration", footer: DebugInfoSummary.configurationFooter(
                    internalDemoMode: DefaultValuesProvider.internalDemoMode)) {
                    ForEach(configurationLines(config), id: \.label) { line in
                        DebugConfigLine(label: line.label, value: line.value)
                    }
                }
                .accessibilityId("debug-info-configuration")

                DebugInfoCard(title: "Host app integration",
                              subtitle: "What the app handles itself — set in Developer tools › Host app integration.") {
                    ForEach(hostRows, id: \.callback) { row in
                        SettingsInfoRow(label: row.callback.docName, value: row.isWired ? "Wired" : "Not wired",
                                        valueColor: row.isWired ? SampleTokens.Colors.successText
                                            : SampleTokens.Colors.danger)
                    }
                    SettingsInfoRow(label: "Intercept URL openings", value: hostStore.urlPolicy.title)
                }

                DebugInfoCard(title: "Build") {
                    SettingsInfoRow(label: "Sample version", value: SettingsView.sampleVersion)
                    SettingsInfoRow(label: "Build", value: SettingsView.sampleBuild)
                    // iOS has no product flavors: the build configuration is what tells two builds apart.
                    SettingsInfoRow(label: "Configuration", value: Self.buildConfiguration)
                }
            }
            .padding(SampleTokens.Spacing.space4)
        }
        .sampleScreenBackground()
        .navigationBarTitle("Debug info", displayMode: .inline)
        .accessibilityId("debug-info-screen")
        .hostAppFooter()
    }

    private var hostRows: [HostIntegrationViewModel.Row] {
        HostIntegrationViewModel.rows(profileWired: clientProfile.isCallbackWired,
                                      profileEditWired: hostStore.isProfileEditWired,
                                      clientObjectWired: HostIntegrationViewModel.liveClientObjectWired(),
                                      groupAccessDeniedWired: hostStore.isGroupAccessDeniedWired)
    }

    private func configurationLines(_ config: SDKConfig?) -> [DebugInfoSummary.Line] {
        let user = userManager.appUser
        return DebugInfoSummary.configurationLines(
            config: config,
            // Without a saved configuration the SDK runs on the build's own key, not on a preset's.
            apiKey: settings.sdkConfig == nil ? APIKeys.apiKey : nil,
            ssoUserId: user?.userId,
            entitlementCount: user == nil ? 0 : AppUserManager.tokenEntitlements(
                known: userManager.currentEntitlements, custom: userManager.currentCustomEntitlements).count,
            theme: DebugInfoSummary.theme(preset: appearance.themePreset, appearance: appearance.appearance),
            language: settings.languageSubtitle)
    }
}

/// The DS card: a title, an optional one-line purpose, the rows, an optional footer pointing at where to edit.
private struct DebugInfoCard<Content: View>: View {
    let title: String
    var subtitle: String?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SampleTokens.Typography.bodyStrong)
                    .foregroundColor(SampleTokens.Colors.text)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(SampleTokens.Typography.callout)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) { content }
            if let footer {
                Text(footer)
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SampleTokens.Spacing.space4)
        .sampleCardSurface()
        .accessibilityElement(children: .contain)
    }
}

/// A Configuration line: the label in a fixed column, the value starting at the same edge on every line, as the
/// Android `CurrentConfigurationBlock`.
private struct DebugConfigLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SampleTokens.Spacing.space3) {
            Text(label)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)
            Text(value)
                .font(SampleTokens.Typography.callout.weight(.medium))
                .foregroundColor(SampleTokens.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

extension SampleSDKStatus {
    /// The status dot: green when every scenario runs, amber while reading only, red when nothing does.
    var color: Color {
        switch self {
        case .signedIn: return SampleTokens.Colors.success
        case .guest, .noSession: return SampleTokens.Colors.warning
        case .notStarted, .unreachable: return SampleTokens.Colors.danger
        }
    }
}

/// The Debug info lines, worded as the Android `SampleConfigSummary` and `DebugInfoScreen`, kept pure for the
/// tests.
enum DebugInfoSummary {
    struct Line: Equatable {
        let label: String
        let value: String
    }

    /// "SSO — no managed fields", "SSO — force login, managed: nickname, bio", "SSO — all fields managed".
    static func authShortLabel(_ kind: SDKConfig.AuthKind) -> String {
        switch kind {
        case let .sso(fields, forceLogin):
            var parts = forceLogin ? ["force login"] : []
            if fields.isEmpty {
                parts.append("no managed fields")
            } else if Set(fields.map { "\($0)" }) == Set(SDKConfig.ProfileField.allCases.map { "\($0)" }) {
                parts.append("all fields managed")
            } else {
                parts.append("managed: " + fields.map { "\($0)" }.joined(separator: ", "))
            }
            return "SSO — " + parts.joined(separator: ", ")
        }
    }

    /// "Guest · read-only", "Connected · <nickname> · <user id>", "Connected · <user id>" or "Not connected". The
    /// iOS profile carries the host's user id only, so the nickname is the one the host app holds.
    static func connection(profile: OctopusProfile?, nickname: String?) -> String {
        guard let profile else { return "Not connected" }
        return connection(isGuest: profile.isGuest, userId: profile.clientUserId, nickname: nickname)
    }

    static func connection(isGuest: Bool, userId: String?, nickname: String?) -> String {
        if isGuest { return "Guest · read-only" }
        let id = userId ?? "—"
        if let nickname, !nickname.isEmpty { return "Connected · \(nickname) · \(id)" }
        return "Connected · \(id)"
    }

    /// The feature env's host, else the custom one, else the host baked into the build.
    static func host(_ config: SDKConfig) -> String {
        if let env = config.featureEnv { return env.apiHost }
        return config.customServer?.host ?? "default (build)"
    }

    static func ssoUser(_ userId: String?) -> String {
        guard let userId, !userId.isEmpty else { return "Not signed in" }
        return userId
    }

    static func theme(preset: SDKThemePreset, appearance: SampleAppearance) -> String {
        "\(preset.title) · \(appearance.summaryTitle)"
    }

    /// What `OctopusSDKProvider.initializeSdkInSSOWithNoFieldsAssociated()` builds when nothing was saved.
    static let builtInConfig = SDKConfig(authKind: .sso(appManagedFields: [], forceLoginOnStrongActions: false))

    /// Where the configuration is edited. Only internal demo mode has a Configuration screen (Settings ›
    /// Configuration); a public build runs the configuration it was built with, so pointing at a row it does not
    /// show would send the tester looking for nothing.
    static func configurationFooter(internalDemoMode: Bool) -> String {
        internalDemoMode ? "Edit in Settings › Configuration" : "Built into this build — it has no Configuration screen"
    }

    /// The saved configuration, else, outside internal demo mode, the one the build initializes the SDK with:
    /// Settings shows "Demo community" there, so Debug info must not read "—".
    static func shownConfig(saved: SDKConfig?, internalDemoMode: Bool) -> SDKConfig? {
        saved ?? (internalDemoMode ? nil : builtInConfig)
    }

    /// The configuration lines in the order of the shared design contract, then the masked API key; `apiKey`, when
    /// set, is the key the SDK really runs on.
    static func configurationLines(config: SDKConfig?, apiKey: String? = nil, ssoUserId: String?,
                                   entitlementCount: Int, theme: String, language: String) -> [Line] {
        let unknown = "—"
        return [
            Line(label: "Server environment", value: config.map(SampleConfigSummary.serverEnvironment) ?? unknown),
            Line(label: "Host", value: config.map(host) ?? unknown),
            Line(label: "Community", value: config.map(SampleConfigSummary.community) ?? unknown),
            Line(label: "API key source", value: config.map(SampleConfigSummary.apiKeySource) ?? unknown),
            Line(label: "SSO user", value: ssoUser(ssoUserId)),
            Line(label: "Entitlements", value: SettingsViewModel.entitlementCount(entitlementCount)),
            Line(label: "Theme", value: theme),
            Line(label: "Language", value: language),
            Line(label: "API key", value: config.map {
                ScenarioCatalog.maskApiKey(apiKey ?? SampleConfigSummary.resolvedApiKey($0, featureEnv: $0.featureEnv))
            } ?? unknown),
        ]
    }
}
