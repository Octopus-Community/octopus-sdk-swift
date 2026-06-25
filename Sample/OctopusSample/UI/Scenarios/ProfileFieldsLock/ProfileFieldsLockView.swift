//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario exercising the per-field profile lock (OCT-1487): pick a preset to apply a community
/// per-field lock (DEBUG override), then open the community to observe the profile + edit screens.
struct ProfileFieldsLockView: View {
    @StateObjectCompat private var viewModel = ProfileFieldsLockViewModel()
    @State private var presentCommunity = false

    private var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug-only: override the community per-field profile lock locally, then open " +
                     "your profile to see the effect on the profile and edit screens.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(ProfileFieldsLockViewModel.Preset.allCases) { preset in
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
                .accessibilityId("qa-preset-profileFieldsLock-clear")
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
            .accessibilityId("profileFieldsLock-openCommunity")

            Spacer()
        }
        .padding()
        .navigationBarTitle("Profile Field Lock", displayMode: .inline)
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
            Text("Applied lock")
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
        .accessibilityId("profileFieldsLock-result")
    }
}
