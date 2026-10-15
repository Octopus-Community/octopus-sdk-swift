//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Settings › Language, mirroring the Android sample's `LanguageScreen`.
struct LanguageSettingsView: View {
    @StateObjectCompat private var viewModel = LanguageSettingsViewModel()

    var body: some View {
        // One card on the screen ground, 16 around and 12 to the footnote, as Android's `LanguageScreen`.
        ScrollView {
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space3) {
                SettingsCard(title: "SDK language",
                             subtitle: "Applies to the Octopus screens only — the sample itself stays in English.") {
                    VStack(spacing: 0) {
                        ForEach(viewModel.options) { option in
                            Button(action: { viewModel.select(option) }) {
                                row(option)
                            }
                            .buttonStyle(.plain)
                            .accessibilityId(option.accessibilityId)
                            .accessibilityAddTraits(viewModel.isSelected(option) ? .isSelected : [])
                        }
                    }
                }
                SettingsFootnote(text: "The override survives a restart. \"Follow system\" hands the choice back "
                                 + "to the device locale.")
            }
            .padding(SampleTokens.Spacing.space4)
        }
        .sampleScreenBackground()
        .navigationBarTitle("Language", displayMode: .inline)
        .accessibilityId("language-screen")
        .hostAppFooter()
    }

    /// A radio and the language, 12 apart, 6 above and below as the Android option row, whose 36 pt is raised to the
    /// touch minimum: Apple asks for 44 pt at least, and the rows are what the tester taps.
    private func row(_ option: LanguageSettingsViewModel.Option) -> some View {
        HStack(spacing: SampleTokens.Spacing.space3) {
            SettingsRadioIndicator(isSelected: viewModel.isSelected(option))
            Text(option.title)
                .font(SampleTokens.Typography.body)
                .foregroundColor(SampleTokens.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .frame(minHeight: SampleTokens.Size.touchMin)
        .contentShape(Rectangle())
    }
}
