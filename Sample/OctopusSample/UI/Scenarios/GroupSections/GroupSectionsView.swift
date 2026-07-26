//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario exercising the sectioned group-list rendering (section title padding + inter-section
/// separator): pick a preset to redistribute the community groups into mock client sections (DEBUG
/// override), then open the community and browse the groups list to observe the section titles and
/// the 1px separator drawn above every block except the first.
struct GroupSectionsView: View {
    @StateObjectCompat private var viewModel = GroupSectionsViewModel()
    @State private var presentCommunity = false

    private var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug-only: redistribute the community groups into mock client sections, then " +
                     "open the community and browse the groups list to see the section titles and the " +
                     "separator drawn above every block except the first.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(GroupSectionsViewModel.Preset.allCases) { preset in
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
                .accessibilityId("qa-preset-groupSections-clear")
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
            .accessibilityId("groupSections-openCommunity")

            Spacer()
        }
        .padding()
        .navigationBarTitle("Group Sections", displayMode: .inline)
        .sheet(isPresented: $presentCommunity) {
            OctopusUIView(octopus: octopus)
        }
        .onDisappear {
            // Restore the backend-driven groups so the next scenario boots clean.
            viewModel.clearOverride()
        }
        .hostAppFooter()
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Applied sections")
                .font(.caption)
                .foregroundColor(.secondary)
            if let preset = viewModel.appliedPreset {
                Text(preset.sectionNames.joined(separator: ", "))
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
        .accessibilityId("groupSections-result")
    }
}
