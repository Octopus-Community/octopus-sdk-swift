//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

// The "Notifications", "Theme & language" and "Host callbacks & events" scenarios' controls, worded as the Android
// sample's sections.

struct NotSeenNotificationsControls: View {
    @Binding var route: CommunityRoute?
    @ObservedObject private var live = ScenarioLiveState.instance
    @ObservedObject private var runner = ScenarioRunner.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            LiveFlowDisplay(label: "notSeenNotificationsCount", value: "\(live.notSeenNotificationsCount)")
            ModeButton(title: "Open Octopus (full-page route)", testId: "qa-preset-notSeenNotifications-1") {
                route = CommunityRoute()
                ScenarioRunner.instance.record(.notSeenNotifications, result: "Pushed CommunityFullScreenRoute()")
            }
            ApiMethodCard(name: "updateNotSeenNotificationsCount()",
                          description: "Fetch latest unseen notification count from server",
                          isRunning: runner.calls[.notSeenNotifications]?.isLoading == true,
                          testId: "qa-preset-notSeenNotifications-2") {
                ScenarioRunner.instance.run(.notSeenNotifications) {
                    let octopus = OctopusSDKProvider.instance.octopus!
                    try await octopus.updateNotSeenNotificationsCount()
                    return "Success: notSeenNotificationsCount=\(octopus.notSeenNotificationsCount)"
                }
            }
        }
    }
}

struct PushNotificationsControls: View {
    @Binding var route: CommunityRoute?
    @State private var postId = SampleFixtures.postText

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Simulates the tap on an Octopus post notification: use the QA post or paste a " +
                "postId, tap the preset, and the sample opens the post the same way its notification handler " +
                "does.")
            ScenarioTextField(title: "Post ID", text: $postId, testId: "pushNotifications-postid-input")
            ModeButton(title: "Open sample notification (deep link)", testId: "qa-preset-pushNotifications-1") {
                let id = postId.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty else {
                    ScenarioRunner.instance.record(
                        .pushNotifications, result: "Parsed, but no postId to open — paste a Post ID first.",
                        isError: true)
                    return
                }
                route = CommunityRoute(postId: id)
                ScenarioRunner.instance.record(.pushNotifications, result: "Success: opening postId=\(id)")
            }
            ScenarioLinkRow(title: "registerNotificationsToken()", subtitle: "Display current APNs token registration info",
                            testId: "pushNotifications-register-token") { PushTokenView() }
        }
    }
}

struct LocaleControls: View {
    @ObservedObject private var language = SampleLanguageManager.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "overrideDefaultLocale(with:) — force a locale, or reset to the system default.")
            if let locale = language.overriddenLocale {
                OverrideActiveBadge(label: "Override active · \(locale.identifier)", testId: "locale-override-badge")
            }
            ModeButton(title: "Force fr", isSelected: language.overriddenLocale?.identifier == "fr",
                       testId: "qa-preset-locale-1") { apply(Locale(identifier: "fr")) }
            ModeButton(title: "Force en", isSelected: language.overriddenLocale?.identifier == "en",
                       testId: "qa-preset-locale-2") { apply(Locale(identifier: "en")) }
            ModeButton(title: "Reset to system", isEnabled: language.overriddenLocale != nil,
                       testId: "qa-preset-locale-3") { apply(nil) }
        }
    }

    private func apply(_ locale: Locale?) {
        language.set(locale: locale)
        ScenarioRunner.instance.record(
            .locale, result: "Success: overrideDefaultLocale(\(locale?.identifier ?? "nil"))")
    }
}

struct ThemeControls: View {
    let presenter: CommunityPresenter
    @ObservedObject private var appearance = SampleAppearanceStore.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "Swaps the theme handed to the community — the same value the Config screen's own " +
                "theme picker writes. Applied live, no restart.")
            ModeButton(title: "Default theme", isSelected: appearance.themePreset == .sdkDefault,
                       testId: "qa-preset-theme-1") { appearance.set(themePreset: .sdkDefault) }
            ModeButton(title: "Custom theme (brand colors + logo)", isSelected: appearance.themePreset == .octopusNavy,
                       testId: "qa-preset-theme-2") { appearance.set(themePreset: .octopusNavy) }
            ScenarioResultLine(text: "Current theme: \(appearance.themePreset.title)", testId: "theme-result")
            ScenarioLinkRow(title: "Custom theme", subtitle: "Colors, fonts and logo, previewed live",
                            testId: "theme-custom-open") {
                CustomThemeView(showFullScreen: presenter.showFullScreen)
            }
        }
    }
}

struct CustomEventsControls: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "track(customEvent:) — send a sample custom tracking event.")
            SecondaryPillButton(title: "Track sample event (no props)", testId: "qa-preset-customEvents-1") {
                send(CustomEvent(name: "sample_test_event"), label: "no props")
            }
            SecondaryPillButton(title: "Track sample event (with props)", testId: "qa-preset-customEvents-2") {
                send(CustomEvent(name: "sample_test_event",
                                 properties: ["sample_prop": .init(value: "sample_value")]),
                     label: "with props")
            }
        }
    }

    private func send(_ event: CustomEvent, label: String) {
        ScenarioRunner.instance.run(.customEvents) {
            try await OctopusSDKProvider.instance.octopus.track(customEvent: event)
            return "Success: tracked sample_test_event (\(label))"
        }
    }
}

struct LifecycleControls: View {
    let presenter: CommunityPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            // The iOS SDK has no reset or stop call: both presets stay visible, disabled.
            ApiMethodCard(name: "reset()", description: "Not exposed by the iOS SDK", isEnabled: false,
                          testId: "qa-preset-lifecycle-2") {}
            ApiMethodCard(name: "stop()", description: "Not exposed by the iOS SDK", isEnabled: false,
                          testId: "qa-preset-lifecycle-3") {}
            Divider()
            Text("Switch community")
                .font(SampleTokens.Typography.bodyStrong)
                .foregroundColor(SampleTokens.Colors.text)
            ScenarioLinkRow(title: "Switch community", subtitle: "Restarts the SDK on another API key",
                            testId: "lifecycle-switch-community") {
                SwitchCommunityView(showFullScreen: presenter.showFullScreen)
            }
            if DefaultValuesProvider.internalDemoMode && DefaultValuesProvider.featureEnvsConfigured {
                ScenarioLinkRow(title: "Feature environments", subtitle: "Target a backend feature env",
                                testId: "lifecycle-feature-envs") { FeatureEnvsView() }
            }
            RunnerResultLine(id: .lifecycle)
        }
    }
}

struct EventsControls: View {
    @ObservedObject private var live = ScenarioLiveState.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "OctopusSDK.eventPublisher — every event this session emitted, most recent last. The " +
                "single preset only clears this local log.")
            LiveFlowDisplay(label: "events.size", value: "\(live.eventCount)")
            SecondaryPillButton(title: "Clear log", testId: "qa-preset-events-1") {
                TrackingManager.instance.clear()
                SampleDebugLog.instance.clear()
            }
            ScenarioResultLine(text: live.lastEvent.map { "Last: \(String(describing: $0))" } ?? "Log empty",
                               testId: "events-result")
            ScenarioLinkRow(title: "Events log", subtitle: "Every event, with its payload",
                            testId: "events-open") { EventsLogView() }
        }
    }
}

struct TrackABTestsControls: View {
    @Binding var route: CommunityRoute?
    @State private var canAccess = true

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            SectionIntro(text: "track(hasAccessToCommunity:) — analytics-only signal of a host-decided cohort. Flip " +
                "the switch, then open the community: Home only opens while the switch is on, and the result " +
                "line reports an error while it's off.")
            Toggle(isOn: $canAccess) {
                Text("Cohort can access")
                    .font(SampleTokens.Typography.body)
                    .foregroundColor(SampleTokens.Colors.text)
            }
            .toggleStyle(SwitchToggleStyle(tint: SampleTokens.Colors.accent))
            .accessibilityId("qa-trackABTests-can-access-switch")
            .onChange(of: canAccess) { OctopusSDKProvider.instance.octopus.track(hasAccessToCommunity: $0) }
            ModeButton(title: "Open Octopus Home Screen", testId: "qa-preset-trackABTests-1") {
                OctopusSDKProvider.instance.octopus.track(hasAccessToCommunity: canAccess)
                if canAccess {
                    route = CommunityRoute()
                    ScenarioRunner.instance.record(.trackABTests, result: "Success: community opened")
                } else {
                    ScenarioRunner.instance.record(
                        .trackABTests, result: "Error: cohort denied - community not opened", isError: true)
                }
            }
            if !canAccess {
                Text("Switch is off — tracking still fires, but Home is not opened and the result below reports " +
                    "an error.")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ForceOctopusABTestsControls: View {
    @ObservedObject private var overrides = ScenarioOverrides.instance
    @ObservedObject private var live = ScenarioLiveState.instance

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
            if let access = overrides.communityAccess {
                OverrideActiveBadge(label: access ? "Forced · granted" : "Forced · denied",
                                    testId: "forceOctopusABTests-override-badge")
            }
            ModeButton(title: "Force cohort · grant community access", isSelected: overrides.communityAccess == true,
                       testId: "qa-preset-forceOctopusABTests-1") { force(true) }
            ModeButton(title: "Force cohort · deny community access", isSelected: overrides.communityAccess == false,
                       testId: "qa-preset-forceOctopusABTests-2") { force(false) }
            SecondaryPillButton(title: "Re-apply current SDK value", isEnabled: overrides.communityAccess != nil,
                                testId: "qa-preset-forceOctopusABTests-3") {
                if let access = overrides.communityAccess { force(access) }
            }
            LiveFlowDisplay(label: "hasAccessToCommunity", value: "\(live.hasAccessToCommunity)")
        }
    }

    private func force(_ access: Bool) {
        ScenarioRunner.instance.run(.forceOctopusABTests) {
            try await OctopusSDKProvider.instance.octopus.overrideCommunityAccess(access)
            ScenarioOverrides.instance.communityAccess = access
            return "Success: overrideCommunityAccess(\(access))"
        }
    }
}
