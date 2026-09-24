//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// Unified Profile community-data scenario (OCT-1374) — reads a member's public Octopus stats so the
/// **host** can render them on its own profile screen, instead of pushing the user into the SDK's
/// native profile.
///
/// Exercises the whole read surface added in 1.13:
/// - `fetchCommunityData(clientUserId:)` — the id kind a host actually has.
/// - `fetchCommunityData(profileId:)` — replayed with the Octopus id the first fetch returned, so both
///   lookup paths are covered without asking QA to paste an opaque id.
/// - `communityDataPublisher(clientUserId:)` — the reactive counterpart; start/stop presets make the
///   observation lifecycle observable.
/// - `OctopusProfile.clientUserId` — surfaced in the live-state panel.
/// - The exactly-one-id contract (compile-time on iOS — see
///   `CommunityDataViewModel.reportIdContract()`).
///
/// Test ids (`qa-preset-communityData-1...6` / `communityData-result`) are the cross-platform contract
/// from the shared pm-tools scenario catalog, applied verbatim so the QA pipeline drives Android, iOS
/// and Flutter with the same ids.
struct CommunityDataView: View {
    @StateObjectCompat private var viewModel = CommunityDataViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reads a member's public Octopus stats with `fetchCommunityData` (one shot) " +
                         "and `communityDataPublisher` (reactive), by Octopus `profileId` or by your " +
                         "own `clientUserId`. Note that `gamification.score` is always null through " +
                         "this API — use `level`.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(CommunityDataViewModel.Preset.allCases) { preset in
                        Button(action: { viewModel.run(preset) }) {
                            Text(preset.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                        }
                        // Only the async presets are disabled while a fetch runs, matching the guard in
                        // `run(_:)`. A disabled button is visible as such in an accessibility dump, so a
                        // refused tap reads as "refused" to the QA pipeline instead of being swallowed.
                        .disabled(viewModel.isLoading && preset.isAsync)
                        .accessibilityId(preset.testId)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                resultPanel
                liveStatePanel
            }
            .padding()
            // Below iOS 15 `hostAppFooter()` degrades to an overlay with no bottom inset, which would
            // sit over the last live-state rows — the ones QA reads.
            .padding(.bottom, 32)
        }
        .navigationBarTitle("Community Data", displayMode: .inline)
        // Presented the way every other entry point presents this screen (iOS 13 falls back to a
        // sheet), matching Flutter's page push and Android's navigation. On iOS 14+ there is no
        // swipe-to-dismiss, so `clientProfile-back` is the QA pipeline's way out.
        .fullScreenCover(item: $viewModel.clientProfileTarget) {
            ClientProfileScreen(clientUserId: $0.id)
        }
        // Deliberately NO `onDisappear` teardown. `observation` is a stored `AnyCancellable`, so ARC
        // cancels it when the view model goes away with the popped view — that is the real guarantee.
        // An `onDisappear` hook fires on events that are not "the user left the scenario" (a cover
        // going up on iOS 13/14, and a tab switch on every version, which `TabView` returns from with
        // the stack intact) and would silently kill a live observation the tester started with preset 3.
        .hostAppFooter()
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Result")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(viewModel.isLoading ? "loading…" : (viewModel.result ?? "none yet — tap a preset."))
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(resultColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        // `.combine` BEFORE the id: without it SwiftUI propagates the identifier onto every child
        // `Text` instead of collapsing the panel, so a query returns several elements and a pipeline
        // reading the first match gets the constant "Result" heading rather than the outcome.
        // Verified on-simulator with `idb ui describe-all`. Flutter already makes the equivalent
        // opt-in (`Semantics(identifier:container: true)` in its scenario scaffold) — iOS was the
        // platform missing it, so there is nothing to propagate there.
        .accessibilityElement(children: .combine)
        .accessibilityId("communityData-result")
    }

    private var resultColor: Color {
        if viewModel.isError { return .red }
        return viewModel.isLoading || viewModel.result == nil ? .secondary : .primary
    }

    /// Everything the scenario currently knows, so a tester can read state without tapping.
    private var liveStatePanel: some View {
        let data = viewModel.data
        let gamification = data?.gamification
        return VStack(alignment: .leading, spacing: 4) {
            Text("Live state")
                .font(.caption)
                .foregroundColor(.secondary)
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
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        // Same reason as the result panel — without `.combine` this panel surfaced as 17 separate
        // elements all carrying the same identifier.
        .accessibilityElement(children: .combine)
        .accessibilityId("communityData-liveState")
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                // No fixed width: a hard label column starves the value column on a small screen and
                // does not scale with Dynamic Type, truncating the very ids QA has to read.
                .layoutPriority(1)
            Text(verbatim: value)
                .font(.system(.footnote, design: .monospaced))
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
