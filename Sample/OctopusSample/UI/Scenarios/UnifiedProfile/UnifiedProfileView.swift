//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// Scenario exercising Unified Profile (OCT-1374): pick a preset to override the community's
/// `exposeClientUserId` activation flag (DEBUG override), then open the community and tap a
/// member's profile to see the `onNavigateToProfileCallback` fire.
struct UnifiedProfileView: View {
    @StateObjectCompat private var viewModel = UnifiedProfileViewModel()
    @State private var presentCommunity = false

    private var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug-only: override the community's Unified Profile activation flag locally, then open " +
                     "the community and tap a member's profile.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Unified Profile only routes profile taps to the host app when BOTH this flag is active AND " +
                     "the `onNavigateToProfileCallback` is wired. Use the controls below to exercise every " +
                     "combination — when a tap is routed to the host, this sample shows its own profile " +
                     "stand-in screen (see ClientProfileManager). The connected user's own floating button then " +
                     "opens the Activity screen, whose top-right menu shows \"Edit my profile\" only while " +
                     "`onNavigateToProfileEdit` is wired below.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(UnifiedProfileViewModel.Mode.allCases) { mode in
                    Button(action: { viewModel.apply(mode) }) {
                        Text(mode.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                    }
                    .accessibilityId(mode.testId)
                }

                Toggle(isOn: Binding(
                    get: { viewModel.callbackWired },
                    set: { viewModel.setCallbackWired($0) }
                )) {
                    Text("onNavigateToProfile wired")
                        .font(.footnote)
                }
                .padding(.top, 4)
                .accessibilityId("unifiedProfile-callbackWired")

                Toggle(isOn: Binding(
                    get: { viewModel.editCallbackWired },
                    set: { viewModel.setEditCallbackWired($0) }
                )) {
                    Text("onNavigateToProfileEdit wired")
                        .font(.footnote)
                }
                .accessibilityId("unifiedProfile-editCallbackWired")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            resultPanel

            Button(action: { presentCommunity = true }) {
                HStack {
                    Image(systemName: "person.crop.circle")
                    Text("Open community")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
            }
            .accessibilityId("unifiedProfile-openCommunity")

            Spacer()
        }
        .padding()
        .navigationBarTitle("Unified Profile", displayMode: .inline)
        .sheet(isPresented: $presentCommunity) {
            OctopusUIView(octopus: octopus)
        }
        .onDisappear {
            // Restore the backend-driven config and the default wiring so the next scenario boots clean.
            viewModel.apply(.backend)
            viewModel.setCallbackWired(true)
            viewModel.setEditCallbackWired(true)
        }
        .hostAppFooter()
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Applied override")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(viewModel.appliedMode.label)
                .font(.system(.footnote, design: .monospaced))
            Text("onNavigateToProfile: \(viewModel.callbackWired ? "wired" : "not wired")")
                .font(.system(.footnote, design: .monospaced))
            Text("onNavigateToProfileEdit: \(viewModel.editCallbackWired ? "wired" : "not wired")")
                .font(.system(.footnote, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .accessibilityId("unifiedProfile-result")
    }
}
