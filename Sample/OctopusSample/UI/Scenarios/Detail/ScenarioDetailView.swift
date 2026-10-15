//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// One scenario, on the Android sample's template: API chip and description, the section's feature state, the
/// "Try it" block (parameters, what you will see, presets, Result), "Verify in Community" and the note.
struct ScenarioDetailView: View {
    let id: ScenarioID
    let presenter: CommunityPresenter

    @ObservedObject private var runner = ScenarioRunner.instance
    @ObservedObject private var toggles = FeatureToggles.instance
    @State private var route: CommunityRoute?
    @Environment(\.presentationMode) private var presentationMode

    private var spec: ScenarioSpec { id.spec }

    var body: some View {
        ScrollView {
            // Android `ScenarioDetailScreen`: 8 between blocks, 6 inside the header.
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
                header
                // Shown whether or not the switch can act in this build, as on Android: the banner
                // states the section's feature. "Change" leads back to the group-header switch, so it
                // is only offered where that switch is enabled.
                if let toggle = id.section.toggle {
                    FeatureStateLine(
                        text: toggle.stateLine(enabled: toggles.isEnabled(toggle)),
                        onChange: toggles.isAvailable(toggle)
                            ? { presentationMode.wrappedValue.dismiss() }
                            : nil)
                }
                ScenarioBlock(title: "Try it", systemImage: "play.fill", tryTone: true) {
                    VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
                        if !spec.parameters.isEmpty {
                            ScenarioParametersBlock(parameters: spec.parameters)
                        }
                        Text("You will see: \(spec.youWillSee)")
                            .font(SampleTokens.Typography.callout)
                            .foregroundColor(SampleTokens.Colors.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityId("scenario-you-will-see")
                        ScenarioControls(id: id, presenter: presenter, route: $route)
                        if spec.hasResult {
                            resultZone
                        }
                        if let runLabel = spec.runLabel {
                            PrimaryPillButton(title: runLabel, isLoading: runner.calls[id]?.isLoading == true,
                                              testId: "scenario-run") {
                                ScenarioRunActions.run(id, route: $route)
                            }
                        }
                    }
                }
                if spec.verifiable {
                    SecondaryPillButton(title: "Verify in Community", systemImage: "arrow.up.right",
                                        testId: "scenario-verify-in-community") {
                        presenter.openTab()
                    }
                }
                if let note = spec.note {
                    Divider()
                    Text("Note")
                        .font(SampleTokens.Typography.label)
                        .foregroundColor(SampleTokens.Colors.text)
                    Text(note)
                        .font(SampleTokens.Typography.callout)
                        .foregroundColor(SampleTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityId("scenario-note")
                }
            }
            .padding(.horizontal, SampleTokens.Spacing.gutter)
            .padding(.vertical, SampleTokens.Spacing.space4)
        }
        .sampleScreenBackground()
        .navigationTitle(spec.title)
        .navigationBarTitleDisplayMode(.inline)
        .communityRoute($route)
        .accessibilityId("scenario-detail-screen")
        .hostAppFooter()
        .onAppear { SampleTabRouter.instance.lastContentBreadcrumb = "Scenarios › \(id.rawValue)" }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ApiPill(name: spec.api)
            Text(spec.subtitle)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var resultZone: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            Text("Result")
                .font(SampleTokens.Typography.label)
                .foregroundColor(SampleTokens.Colors.text)
            if let call = runner.calls[id] {
                if call.isLoading {
                    ResultSkeleton()
                } else {
                    CodeResultBlock(call: call, testId: spec.resultTestId)
                }
            } else {
                Text("Not run yet")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .accessibilityId("scenario-result-idle")
            }
        }
    }
}

/// The detail's primary run button, for the scenarios whose spec names one.
@MainActor
enum ScenarioRunActions {
    static func run(_ id: ScenarioID, route: Binding<CommunityRoute?>) {
        let runner = ScenarioRunner.instance
        let octopus = OctopusSDKProvider.instance.octopus
        switch id {
        case .groups:
            runner.run(.groups) {
                try await octopus?.fetchGroups()
                return "Success: \(octopus?.groups.count ?? 0) group(s) fetched"
            }
        case .trackABTests:
            octopus?.track(hasAccessToCommunity: true)
            runner.record(.trackABTests, result: "Success: track(hasAccessToCommunity: true) sent")
        default:
            break
        }
    }
}

/// The outcome of the scenario's last preset, for the scenarios whose detail has no Result zone.
struct RunnerResultLine: View {
    let id: ScenarioID
    var placeholder: String?

    @ObservedObject private var runner = ScenarioRunner.instance

    var body: some View {
        if let call = runner.calls[id], call.isLoading {
            ResultSkeleton()
        } else {
            ScenarioResultLine(text: runner.calls[id]?.result ?? placeholder,
                               isError: runner.calls[id]?.isError ?? false,
                               testId: "\(id.rawValue)-result")
        }
    }
}

/// Dispatches to the controls of one scenario.
struct ScenarioControls: View {
    let id: ScenarioID
    let presenter: CommunityPresenter
    @Binding var route: CommunityRoute?

    var body: some View {
        switch id {
        case .unifiedProfile: UnifiedProfileControls()
        case .connection: ConnectionControls()
        case .communityData: CommunityDataControls()
        case .profileFieldsLock: ProfileFieldsLockControls()
        case .termsAcceptance: TermsAcceptanceControls()
        case .consentTexts: ConsentTextsControls()
        case .forceNicknameChoice: ForceNicknameChoiceControls()
        case .refreshEntitlements: RefreshEntitlementsControls()
        case .initialScreen: InitialScreenControls()
        case .fullscreen: FullscreenControls(route: $route)
        case .modal: ContainerControls(id: .modal, presenter: presenter)
        case .sheet: ContainerControls(id: .sheet, presenter: presenter)
        case .groups: GroupsControls()
        case .syncFollowGroups: SyncFollowGroupsControls()
        case .communityAccess: CommunityAccessControls()
        case .bridge: BridgeControls(presenter: presenter)
        case .createPost: CreatePostControls()
        case .reactions: ReactionsControls()
        case .contentOptions: ContentOptionsControls()
        case .groupAccessDenied: GroupAccessDeniedControls()
        case .screenStates: ScreenStatesControls()
        case .groupSections: GroupSectionsControls()
        case .notSeenNotifications: NotSeenNotificationsControls(route: $route)
        case .pushNotifications: PushNotificationsControls(route: $route)
        case .locale: LocaleControls()
        case .theme: ThemeControls(presenter: presenter)
        case .customEvents: CustomEventsControls()
        case .lifecycle: LifecycleControls(presenter: presenter)
        case .events: EventsControls()
        case .trackABTests: TrackABTestsControls(route: $route)
        case .forceOctopusABTests: ForceOctopusABTestsControls()
        }
    }
}
