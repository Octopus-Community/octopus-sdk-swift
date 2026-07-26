//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario exercising the explicit terms-acceptance modes: pick a mode (DEBUG override), then open
/// the community and try to post / comment / reply. In an explicit mode a consent bottom sheet is
/// shown at the first contribution.
///
/// Note: consent is memorized via the profile's `hasAcceptedCgu`, so the sheet only appears for a
/// user who hasn't accepted yet — use a fresh guest / new user to see it.
struct TermsAcceptanceModeView: View {
    @StateObjectCompat private var viewModel = TermsAcceptanceModeViewModel()
    @State private var presentCommunity = false

    private var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug-only: override the community terms-acceptance mode locally, then open the " +
                     "community and try to post/comment/reply. In an explicit mode a consent sheet is " +
                     "shown at the first contribution.\n\nConsent is remembered per user " +
                     "(hasAcceptedCgu) — use a fresh guest / new user to see the sheet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(TermsAcceptanceModeViewModel.Preset.allCases) { preset in
                    Button(action: { viewModel.apply(preset) }) {
                        Text(preset.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                    }
                    .accessibilityId(preset.testId)
                }

                Button(action: { viewModel.clearOverride() }) {
                    Text("Clear override (backend default)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                }
                .accessibilityId("qa-preset-termsAcceptanceMode-clear")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            resultPanel

            Button(action: { presentCommunity = true }) {
                HStack {
                    Image(systemName: "text.badge.checkmark")
                    Text("Open community")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
            }
            .accessibilityId("termsAcceptanceMode-openCommunity")

            Spacer()
        }
        .padding()
        .navigationBarTitle("Terms Acceptance", displayMode: .inline)
        .sheet(isPresented: $presentCommunity) {
            OctopusUIView(octopus: octopus)
        }
        .onDisappear {
            // Restore the backend-driven config so the next scenario boots clean.
            viewModel.clearOverride()
        }
        .hostAppFooter()
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Applied mode")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(viewModel.appliedPreset?.label ?? "none (backend default)")
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(viewModel.appliedPreset == nil ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .accessibilityId("termsAcceptanceMode-result")
    }
}
