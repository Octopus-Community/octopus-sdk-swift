//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
@_spi(OctopusInternalTesting) import Octopus
import OctopusCore

// The "Sign-in & user" scenarios' controls, worded as the Android sample's sections.

struct UnifiedProfileControls: View {
    @StateObjectCompat private var viewModel = UnifiedProfileViewModel()
    @State private var showsOverride = false

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "One switch sets both inputs: the community flag that exposes the app's user id, and " +
                "the callback that opens the host's own profile screen.")
            Toggle(isOn: Binding(get: { viewModel.isEnabled }, set: { viewModel.setEnabled($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unified profile")
                        .font(SampleTokens.Typography.bodyStrong)
                        .foregroundColor(SampleTokens.Colors.text)
                    Text(UnifiedProfileViewModel.effectLine(active: viewModel.isActive))
                        .font(SampleTokens.Typography.caption)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SampleTokens.Colors.accent))
            .accessibilityId("config-unified-profile")
            Text("Applies live: the next profile tap follows the switch, no restart needed.")
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .accessibilityId("unified-profile-restart-note")
            Button {
                withAnimation { showsOverride.toggle() }
            } label: {
                HStack {
                    Text("Backend flag override")
                        .font(SampleTokens.Typography.bodyStrong)
                        .foregroundColor(SampleTokens.Colors.text)
                    Spacer()
                    Image(systemName: showsOverride ? "chevron.up" : "chevron.down")
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: SampleTokens.Size.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityId("unified-profile-override-toggle")
            if showsOverride {
                SectionIntro(text: "Inspect either condition independently. A community switch restores the " +
                    "scenario switch's flag override.")
                ForEach(UnifiedProfileViewModel.Mode.allCases) { mode in
                    ModeButton(title: mode.label, isSelected: viewModel.appliedMode == mode, testId: mode.testId) {
                        viewModel.apply(mode)
                    }
                }
            }
        }
    }
}

struct ConnectionControls: View {
    @ObservedObject private var live = ScenarioLiveState.instance
    @ObservedObject private var runner = ScenarioRunner.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            LiveFlowDisplay(label: "connectionState", value: live.connectionState)
            LiveFlowDisplay(label: "isUserConnected", value: "\(live.isUserConnected)")
            ApiMethodCard(name: "connectUser()", description: "Connect the stored SSO user to Octopus",
                          isRunning: runner.calls[.connection]?.isLoading == true,
                          testId: "qa-preset-connection-1") { connect() }
            ApiMethodCard(name: "disconnectUser()", description: "Disconnect the current user",
                          isRunning: runner.calls[.connection]?.isLoading == true,
                          testId: "qa-preset-connection-5") {
                ScenarioRunner.instance.run(.connection) {
                    try await AppUserManager.instance.disconnect()
                    return "Success: disconnectUser()"
                }
            }
        }
    }

    private func connect() {
        ScenarioRunner.instance.run(.connection) {
            let manager = AppUserManager.instance
            guard manager.appUser != nil else {
                throw ScenarioFailure("No stored SSO user — sign in from Settings > Account first.")
            }
            let previous = manager.lastConnectOutcome?.id
            manager.reconnect()
            for await outcome in manager.$lastConnectOutcome.values {
                guard let outcome, outcome.id != previous else { continue }
                if let failure = outcome.failure { throw ScenarioFailure("Error: \(failure)") }
                return "Success: connectUser(\(outcome.userId))"
            }
            throw ScenarioFailure("Error: no connection outcome")
        }
    }
}

struct CommunityDataControls: View {
    var body: some View {
        CommunityDataSection()
    }
}

struct ProfileFieldsLockControls: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance

    private static let presets: [(label: String, lock: ProfileFieldsLock)] = [
        ("All editable (default / no-op)", .allEditable),
        ("Pseudo + avatar read-only, bio hidden",
         ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .disabled)),
        ("Bio-only editable", ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .editable)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Debug-only: override the community per-field profile lock locally, then open " +
                "your profile to see the effect on the profile and edit screens.")
            if overrides.profileFieldsLock != nil {
                OverrideActiveBadge(label: "Override active", testId: "profileFieldsLock-override-badge")
            }
            ForEach(Array(Self.presets.enumerated()), id: \.offset) { index, preset in
                ModeButton(title: preset.label, isSelected: overrides.profileFieldsLock == preset.lock,
                           testId: "qa-preset-profileFieldsLock-\(index + 1)") {
                    overrides.apply(profileFieldsLock: preset.lock)
                }
            }
            ModeButton(title: "Clear override (backend default)", isEnabled: overrides.profileFieldsLock != nil,
                       testId: "qa-preset-profileFieldsLock-clear") {
                overrides.apply(profileFieldsLock: nil)
            }
            ScenarioResultLine(
                text: "Applied: \(overrides.profileFieldsLock.map(OverrideLabels.lockLabel) ?? OverrideLabels.backendDefault)",
                testId: "profileFieldsLock-result")
        }
    }
}

struct ContentOptionsControls: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Debug-only: override the community content options locally, then open the post " +
                "composer (or a comment / reply input) to see the matching picture / poll affordance disappear, " +
                "or publish a post with an image and no text.")
            if overrides.contentOptions != nil {
                OverrideActiveBadge(label: "Override active", testId: "contentOptions-override-badge")
            }
            ForEach(Array(OverrideLabels.contentOptionsPresets.enumerated()), id: \.offset) { index, preset in
                ModeButton(title: preset.label, isSelected: overrides.contentOptions == preset.options,
                           testId: "qa-preset-contentOptions-\(index + 1)") {
                    overrides.apply(contentOptions: preset.options)
                }
            }
            ModeButton(title: "Clear override (backend default)", isEnabled: overrides.contentOptions != nil,
                       testId: "qa-preset-contentOptions-clear") {
                overrides.apply(contentOptions: nil)
            }
            ScenarioResultLine(
                text: "Applied: \(overrides.contentOptions.map(OverrideLabels.contentOptionsLabel) ?? OverrideLabels.backendDefault)",
                testId: "contentOptions-result")
        }
    }
}

struct TermsAcceptanceControls: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance

    private static let presets: [(label: String, mode: TermsAcceptanceMode)] = [
        ("Implicit (default / no-op)", .implicit),
        ("Explicit — multi checkbox", .explicitMultiCheckbox),
        ("Explicit — single checkbox", .explicitSingleCheckbox),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Debug-only: override the community terms-acceptance mode locally (applied live — " +
                "switch to the Community tab to see it). In an explicit mode a consent sheet is shown at the " +
                "first contribution, for a user who has not accepted the CGU yet.")
            if overrides.termsAcceptance != nil {
                OverrideActiveBadge(label: "Override active", testId: "termsAcceptance-override-badge")
            }
            ForEach(Array(Self.presets.enumerated()), id: \.offset) { index, preset in
                ModeButton(title: preset.label, isSelected: overrides.termsAcceptance == preset.mode,
                           testId: "qa-preset-termsAcceptance-\(index + 1)") {
                    overrides.apply(termsAcceptance: preset.mode)
                }
            }
            ModeButton(title: "Clear override (backend default)", isEnabled: overrides.termsAcceptance != nil,
                       testId: "qa-preset-termsAcceptance-clear") {
                overrides.apply(termsAcceptance: nil)
            }
            ScenarioResultLine(text: resultLine, testId: "termsAcceptance-result")
        }
    }

    private var resultLine: String {
        guard let mode = overrides.termsAcceptance else { return "Effective mode: backend value" }
        return "Effective mode: \(OverrideLabels.termsLabel(mode))  (local override)"
    }
}

struct ConsentTextsControls: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Debug-only: show the community's own consent wordings (applied live — switch to " +
                "the Community tab to see them). Each preset also forces its terms-acceptance mode. An empty " +
                "wording keeps the SDK's, and texts written for another mode are ignored.")
            if hasOverride {
                OverrideActiveBadge(label: "Override active", testId: "consentTexts-override-badge")
            }
            ForEach(Array(ConsentTextsPresets.all.enumerated()), id: \.offset) { _, preset in
                ModeButton(title: preset.label,
                           isSelected: overrides.consentTexts == preset.texts
                               && overrides.termsAcceptance == preset.mode,
                           testId: preset.testId) {
                    overrides.apply(termsAcceptance: preset.mode)
                    overrides.apply(consentTexts: preset.texts)
                }
            }
            // Stays on screen while disabled: the QA pipeline resolves its id from a clean state too.
            ModeButton(title: "Clear overrides (backend texts and mode)", isEnabled: hasOverride,
                       testId: ConsentTextsPresets.clearTestId) {
                overrides.apply(consentTexts: nil)
                overrides.apply(termsAcceptance: nil)
            }
            ScenarioResultLine(text: resultLine, testId: "consentTexts-result")
        }
    }

    private var hasOverride: Bool {
        overrides.consentTexts != nil || overrides.termsAcceptance != nil
    }

    /// The overrides the sample applied: the SDK exposes no getter for the effective config outside the package.
    private var resultLine: String {
        guard hasOverride else { return "Effective: backend texts and mode  (backend value)" }
        let mode = overrides.termsAcceptance.map(ConsentTextsPresets.modeLabel) ?? "backend mode"
        let texts = overrides.consentTexts.map { ConsentTextsPresets.describe($0) } ?? "backend texts"
        return "Effective: \(mode) · \(texts)  (local override)"
    }
}

struct ForceNicknameChoiceControls: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Debug-only: override the community's forceNicknameChoice locally (applied live — " +
                "switch to the Community tab to see it). A member who has not confirmed a nickname yet gets the " +
                "nickname choice screen at their first post, comment or reply: empty field when on, prefilled " +
                "with the generated nickname when off.")
            if overrides.forceNicknameChoice != nil {
                OverrideActiveBadge(label: "Override active", testId: "forceNicknameChoice-override-badge")
            }
            ModeButton(title: "On — the member types a nickname", isSelected: overrides.forceNicknameChoice == true,
                       testId: "qa-preset-forceNicknameChoice-1") {
                overrides.apply(forceNicknameChoice: true)
            }
            ModeButton(title: "Off — the generated nickname is prefilled",
                       isSelected: overrides.forceNicknameChoice == false,
                       testId: "qa-preset-forceNicknameChoice-2") {
                overrides.apply(forceNicknameChoice: false)
            }
            ModeButton(title: "Clear override (backend default)", isEnabled: overrides.forceNicknameChoice != nil,
                       testId: "qa-preset-forceNicknameChoice-clear") {
                overrides.apply(forceNicknameChoice: nil)
            }
            ScenarioResultLine(text: resultLine, testId: "forceNicknameChoice-result")
        }
    }

    private var resultLine: String {
        guard let enabled = overrides.forceNicknameChoice else { return "Effective value: backend value" }
        return "Effective value: \(OverrideLabels.tick(enabled))  (local override)"
    }
}

struct RefreshEntitlementsControls: View {
    @ObservedObject private var runner = ScenarioRunner.instance

    var body: some View {
        let isLoading = runner.calls[.refreshEntitlements]?.isLoading == true
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Edit the demo user's entitlements in Settings > Account, then re-issue them here: " +
                "the community picks them up without signing out.")
            SecondaryPillButton(title: isLoading ? "Refreshing…" : "Refresh entitlements", isLoading: isLoading,
                                testId: "qa-preset-refreshEntitlements-1") {
                ScenarioRunner.instance.run(.refreshEntitlements) {
                    try await OctopusSDKProvider.instance.octopus.refreshEntitlements()
                    return "Success: entitlements refreshed"
                }
            }
            RunnerResultLine(id: .refreshEntitlements)
        }
    }
}
