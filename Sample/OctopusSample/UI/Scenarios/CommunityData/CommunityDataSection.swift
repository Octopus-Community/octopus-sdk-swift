//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// Unified Profile community-data scenario — reads a member's public Octopus stats so the
/// **host** can render them on its own profile screen, instead of pushing the user into the SDK's
/// native profile.
///
/// Rendered inline in the scenario detail screen, in the order of the Android sample's
/// `CommunityDataSection`: intro, the six presets, the result and live-state panels, then the raw
/// one-shot lookup on a hand-typed id.
///
/// Exercises the whole read surface added in 1.13:
/// - `fetchCommunityData(clientUserId:)` — the id kind a host actually has.
/// - `fetchCommunityData(profileId:)` — replayed with the Octopus id the first fetch returned, so both
///   lookup paths are covered without asking QA to paste an opaque id, and once more on any typed id.
/// - `communityDataPublisher(clientUserId:)` — the reactive counterpart; start/stop presets make the
///   observation lifecycle observable.
/// - `OctopusProfile.clientUserId` — surfaced in the live-state panel.
/// - The exactly-one-id contract (compile-time on iOS — see
///   `CommunityDataViewModel.reportIdContract()`).
///
/// Test ids (`qa-preset-communityData-1...6` / `communityData-result`) are the cross-platform contract
/// from the shared QA scenario catalog, applied verbatim so the QA pipeline drives Android, iOS
/// and Flutter with the same ids.
struct CommunityDataSection: View {
    @StateObjectCompat private var viewModel = CommunityDataViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            SectionIntro(text: "Reads a member's public Octopus stats with `fetchCommunityData` (one shot) " +
                         "and `communityDataPublisher` (reactive), by Octopus `profileId` or by your " +
                         "own `clientUserId`. Note that `gamification.score` is always null through " +
                         "this API — use `level`.")

            ForEach(CommunityDataViewModel.Preset.allCases) { preset in
                // Only the async presets are disabled while a fetch runs, matching the guard in
                // `run(_:)`. A disabled button is visible as such in an accessibility dump, so a
                // refused tap reads as "refused" to the QA pipeline instead of being swallowed.
                SecondaryPillButton(title: preset.label,
                                    isEnabled: !(viewModel.isLoading && preset.isAsync),
                                    testId: preset.testId) {
                    viewModel.run(preset)
                }
            }

            resultPanel
            liveStatePanel

            Divider()

            // Raw one-shot lookup on an arbitrary Octopus id, as on Android: the presets deliberately
            // never ask for a hand-typed id.
            ControlsHeading(text: "fetchCommunityData(profileId:) — any id")
            ScenarioTextField(title: "User ID", text: $viewModel.rawProfileIdInput,
                              testId: "communityData-rawUserId")
            ApiMethodCard(name: "fetchCommunityData(profileId:)",
                          description: "Fetch a user's message count + gamification (read-only).",
                          isRunning: viewModel.isRawFetching,
                          testId: "communityData-rawFetch") {
                viewModel.fetchRawProfileId()
            }
            ScenarioResultLine(text: viewModel.rawFetchResult, isError: viewModel.rawFetchIsError,
                               testId: "communityData-rawResult")
        }
        // Presented the way every other entry point presents this screen (iOS 13 falls back to a
        // sheet). On iOS 14+ there is no swipe-to-dismiss, so `clientProfile-back` is the QA
        // pipeline's way out.
        .dismissedOnPushRouting($viewModel.clientProfileTarget)
        .fullScreenCover(item: $viewModel.clientProfileTarget) {
            ClientProfileScreen(clientUserId: $0.id)
        }
        // Deliberately NO `onDisappear` teardown. `observation` is a stored `AnyCancellable`, so ARC
        // cancels it when the view model goes away with the popped view — that is the real guarantee.
        // An `onDisappear` hook fires on events that are not "the user left the scenario" (a cover
        // going up on iOS 13/14, and a tab switch on every version, which `TabView` returns from with
        // the stack intact) and would silently kill a live observation the tester started with preset 3.
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            Text("Result")
                .font(Font.subheadline.weight(.bold))
                .foregroundColor(SampleTokens.Colors.text)
            Text(viewModel.isLoading ? "loading…" : (viewModel.result ?? "none yet — tap a preset."))
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(resultColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SampleTokens.Spacing.space3)
        .background(panelShape.fill(SampleTokens.Colors.surface3))
        // `.combine` BEFORE the id: without it SwiftUI propagates the identifier onto every child
        // `Text` instead of collapsing the panel, so a query returns several elements and a pipeline
        // reading the first match gets the constant "Result" heading rather than the outcome.
        .accessibilityElement(children: .combine)
        .accessibilityId("communityData-result")
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
    }

    private var resultColor: Color {
        if viewModel.isError { return SampleTokens.Colors.danger }
        return viewModel.isLoading || viewModel.result == nil
            ? SampleTokens.Colors.textSecondary : SampleTokens.Colors.text
    }

    /// Everything the scenario currently knows, so a tester can read state without tapping.
    private var liveStatePanel: some View {
        let data = viewModel.data
        let gamification = data?.gamification
        return VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            Text("Live state")
                .font(Font.subheadline.weight(.bold))
                .foregroundColor(SampleTokens.Colors.text)
            line("profile.clientUserId", viewModel.profileClientUserId ?? "—")
            line("lookup clientUserId", viewModel.lookupClientUserId ?? "—")
            line("observing", viewModel.isObserving ? "yes" : "no")
            line("last value from", viewModel.source)
            line("profileId", data?.profileId ?? "—")
            line("messageCount", data?.messageCount.map(String.init) ?? "null")
            line("gamification.level", gamification.map { String($0.level) } ?? "null")
            line("gamification.score", gamification?.score.map(String.init) ?? "null")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SampleTokens.Spacing.space3)
        .background(panelShape.fill(SampleTokens.Colors.surface3))
        // Same reason as the result panel — without `.combine` this panel surfaced as 17 separate
        // elements all carrying the same identifier.
        .accessibilityElement(children: .combine)
        .accessibilityId("communityData-liveState")
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: SampleTokens.Spacing.space2) {
            Text(label)
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                // No fixed width: a hard label column starves the value column on a small screen and
                // does not scale with Dynamic Type, truncating the very ids QA has to read.
                .layoutPriority(1)
            Text(verbatim: value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(SampleTokens.Colors.text)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
