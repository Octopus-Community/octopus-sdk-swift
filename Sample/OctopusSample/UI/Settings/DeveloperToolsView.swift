//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Settings › Developer tools, the iOS twin of the Android screen: Host app integration sets what the app
/// handles, the Events log, Debug info and Debug console read what the SDK did.
struct DeveloperToolsView: View {
    @ObservedObject private var log = SampleDebugLog.instance
    @State private var showConsole = false

    var body: some View {
        // Full-bleed 56 pt rows with the icon gutter and 52-inset dividers, then the footnote, as Android.
        ScrollView {
            VStack(spacing: 0) {
                NavigationLink(destination: HostIntegrationView()) {
                    SettingsSummaryRow(systemImage: "slider.horizontal.3", title: "Host app integration",
                                       subtitle: "Profile, sign-in, links: what the app handles")
                }
                .buttonStyle(SettingsRowButtonStyle())
                .accessibilityId("devtools-host-integration-row")
                SettingsRowDivider()
                NavigationLink(destination: EventsLogView()) {
                    SettingsSummaryRow(systemImage: "bell", title: "Events log",
                                       subtitle: "\(log.entries.count) events · live")
                }
                .buttonStyle(SettingsRowButtonStyle())
                .accessibilityId("devtools-events-row")
                SettingsRowDivider()
                NavigationLink(destination: DebugInfoView()) {
                    // The toggles ride in the subtitle: "which switches were on?" is the first question when a
                    // build behaves unexpectedly.
                    SettingsSummaryRow(systemImage: "info.circle", title: "Debug info",
                                       subtitle: "SDK \(OctopusCore.version) · build \(SettingsView.sampleBuild) · "
                                        + FeatureToggles.instance.summaryLine)
                }
                .buttonStyle(SettingsRowButtonStyle())
                .accessibilityId("devtools-debug-info-row")
                SettingsRowDivider()
                Button(action: { showConsole = true }) {
                    SettingsSummaryRow(systemImage: "ladybug", title: "Debug console",
                                       subtitle: "Logs every feature toggle → SDK config rebuilt")
                }
                .buttonStyle(SettingsRowButtonStyle())
                .accessibilityId("devtools-debug-console-row")
                SettingsFootnote(text: "Host app integration sets what the app handles; the other three read what "
                                 + "the SDK did.")
                    .padding(.horizontal, SampleTokens.Spacing.space4)
                    .padding(.vertical, SampleTokens.Spacing.space5)
            }
        }
        .sampleScreenBackground()
        .navigationBarTitle("Developer tools", displayMode: .inline)
        .accessibilityId("developer-tools-screen")
        .sheet(isPresented: $showConsole) { DebugConsoleSheet(isPresented: $showConsole) }
        .hostAppFooter()
    }
}
