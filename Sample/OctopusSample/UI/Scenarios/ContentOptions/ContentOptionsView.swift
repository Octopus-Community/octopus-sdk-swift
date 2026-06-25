//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario exercising the per-content-type content options (OCT-1426): pick a preset to apply a
/// community content-options config (DEBUG override), then open the community to observe the
/// picture / poll affordances hidden on the post composer, comment input and reply input.
struct ContentOptionsView: View {
    @StateObjectCompat private var viewModel = ContentOptionsViewModel()
    @State private var presentCommunity = false

    private var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug-only: override the community content options locally, then open the " +
                     "community and a post to see the picture / poll affordances hidden on the " +
                     "composer, comment and reply inputs.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(ContentOptionsViewModel.Preset.allCases) { preset in
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
                .accessibilityId("qa-preset-contentOptions-clear")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            resultPanel

            Button(action: { presentCommunity = true }) {
                HStack {
                    Image(systemName: "rectangle.stack.badge.plus")
                    Text("Open community")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
            }
            .accessibilityId("contentOptions-openCommunity")

            Spacer()
        }
        .padding()
        .navigationBarTitle("Content Options", displayMode: .inline)
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
            Text("Applied options")
                .font(.caption)
                .foregroundColor(.secondary)
            if let preset = viewModel.appliedPreset {
                Text(viewModel.describe(preset))
                    .font(.system(.footnote, design: .monospaced))
            } else {
                Text("none (backend default)")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .accessibilityId("contentOptions-result")
    }
}
