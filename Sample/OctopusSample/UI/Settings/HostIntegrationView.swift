//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Settings › Host app integration, mirroring the Android sample's `HostIntegrationScreen`: how this host app
/// integrates the SDK UI.
///
/// What the sample app handles itself when the community asks: the navigation mode, the host callbacks (with
/// the wired count, required ones locked on), the URL policy and Restart now. Everything applies at once on iOS,
/// where the SDK reads its callbacks when it needs them; Restart now only brings the community back to its feed.
struct HostIntegrationView: View {
    @ObservedObject private var navigation = CommunityNavigationManager.instance
    @StateObjectCompat private var viewModel = HostIntegrationViewModel()

    var body: some View {
        // Android's `HostIntegrationScreen`: one column 16 in, 12 from the top, 8 between blocks.
        ScrollView {
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
                Text("What the sample app handles itself when the community asks. Everything is on by default, " +
                     "like a complete integration; switch one off to see what a host that skips it gets.")
                    .font(SampleTokens.Typography.callout)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityId("host-integration-intro")

                navigationCard
                SettingsFootnote(text: "Saved at once. Changing it closes the community and reopens it on its feed.")

                SettingsGroupHeader(title: "Callbacks", countText: viewModel.countLabel,
                                    countLabel: viewModel.countAccessibilityLabel)
                    .accessibilityId("host-integration-callbacks-count")
                SettingsListGroup {
                    ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { SettingsListDivider() }
                        HostCallbackRow(row: row) { viewModel.set(row.callback, wired: $0) }
                    }
                }

                SettingsGroupHeader(title: "Intercept URL openings")
                Text("onNavigateToURLCallback")
                    .font(SampleTokens.Typography.callout)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                SettingsListGroup {
                    ForEach(Array(HostURLPolicy.allCases.enumerated()), id: \.element.id) { index, policy in
                        if index > 0 { SettingsListDivider() }
                        urlRow(policy)
                    }
                }

                Text("Callback and URL changes apply at once: the iOS SDK reads each callback when it needs it.")
                    .font(SampleTokens.Typography.callout)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, SampleTokens.Spacing.space4)
                PrimaryPillButton(title: "Restart now", testId: "host-integration-restart",
                                  action: viewModel.restartNow)
                SettingsFootnote(text: "Closes the community and opens it again on its feed.")
            }
            .padding(.horizontal, SampleTokens.Spacing.space4)
            .padding(.vertical, SampleTokens.Spacing.space3)
        }
        .onAppear(perform: viewModel.refresh)
        .sampleScreenBackground()
        .navigationBarTitle("Host app integration", displayMode: .inline)
        .accessibilityId("host-integration-screen")
        .hostAppFooter()
    }
}

private extension HostIntegrationView {
    var navigationCard: some View {
        SettingsCard(title: "Community navigation", subtitle: "Show tabs or use the whole screen.") {
            Picker("Community navigation", selection: $navigation.mode) {
                ForEach(CommunityNavigation.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityId("community-navigation-select")
            // iOS only: what the mode changes, since a change here closes the community and reopens it at once.
            Text(navigation.mode.summary)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityId("community-navigation-summary")
        }
    }

    /// Android's `UrlOptionRow`: a radio 12 from the label and its effect, 16/8 padding, 56 pt minimum.
    func urlRow(_ policy: HostURLPolicy) -> some View {
        Button(action: { viewModel.select(policy) }, label: {
            HStack(spacing: SampleTokens.Spacing.space3) {
                SettingsRadioIndicator(isSelected: viewModel.urlPolicy == policy)
                VStack(alignment: .leading, spacing: 2) {
                    Text(policy.title)
                        .font(SampleTokens.Typography.body)
                        .foregroundColor(SampleTokens.Colors.text)
                    Text(policy.summary)
                        .font(SampleTokens.Typography.callout)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SampleTokens.Spacing.space4)
            .padding(.vertical, SampleTokens.Spacing.space2)
            .frame(minHeight: SampleTokens.Size.rowMin)
            .contentShape(Rectangle())
        })
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityAddTraits(viewModel.urlPolicy == policy ? .isSelected : [])
        .accessibilityId("host-integration-url-\(policy.id)")
    }
}

/// One host callback, as Android's `SampleSwitchRow`: the doc name over the SDK symbol and what the tester sees,
/// the switch at the end, 16 apart, 56 pt minimum, 16/8 inside the group. A row locked on adds a lock and the
/// reason under the effect, so the greyed switch never stands alone.
private struct HostCallbackRow: View {
    let row: HostIntegrationViewModel.Row
    let setWired: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { row.isWired }, set: setWired)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.callback.docName)
                    .font(SampleTokens.Typography.body)
                    .foregroundColor(SampleTokens.Colors.text)
                // Verbatim: an interpolated literal would be a localized key, extracted into the string catalog.
                Text(verbatim: "\(row.callback.apiName)\n\(row.effect)")
                    .font(SampleTokens.Typography.callout)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let lock = row.lock {
                    Label(lock.reason, systemImage: "lock.fill")
                        .font(SampleTokens.Typography.callout)
                        .foregroundColor(SampleTokens.Colors.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(SampleTokens.Colors.accent)
        .disabled(!row.isSwitchable)
        .frame(minHeight: SampleTokens.Size.rowMin)
        .padding(.horizontal, SampleTokens.Spacing.space4)
        .padding(.vertical, SampleTokens.Spacing.space2)
        .accessibilityId(row.accessibilityId)
    }
}

private extension CommunityNavigation {
    /// What the tester sees in each mode, in one sentence.
    var summary: String {
        switch self {
        case .inTab:
            return "Posts, profiles, groups and comments open inside the Community tab. The tab bar stays " +
                "visible, and a second tap on Community goes back to the feed."
        case .fullScreen:
            return "The community opens above the tabs, with its own close button, and covers the tab bar " +
                "on every screen. Closing it returns to the host app."
        }
    }
}
