//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Settings › Appearance, mirroring the Android sample's `AppearanceScreen`: light or dark for the whole app,
/// and the theme preset handed to the SDK. Both apply at once, without a restart.
struct AppearanceView: View {
    @ObservedObject private var store = SampleAppearanceStore.instance

    var body: some View {
        List {
            Group {
                Section(header: SettingsSectionHeader(
                    title: "Appearance", subtitle: "Applies to the sample and to the SDK surface it hosts.")) {
                    Picker("Appearance", selection: Binding(
                        get: { store.appearance },
                        set: { store.set(appearance: $0) })
                    ) {
                        ForEach(SampleAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, SampleTokens.Spacing.space2)
                    .accessibilityId("appearance-mode-select")
                }
                Section(
                    header: SettingsSectionHeader(
                        title: "Theme preset",
                        subtitle: "\"SDK default\" hands the SDK no theme — what a fresh integration looks like."),
                    footer: Text("Changing the preset re-themes the community tab immediately — no restart.")
                ) {
                    Picker("Theme preset", selection: Binding(
                        get: { store.themePreset },
                        set: { store.set(themePreset: $0) })
                    ) {
                        ForEach(SDKThemePreset.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, SampleTokens.Spacing.space2)
                    .accessibilityId("appearance-preset-select")
                }
            }
            .sampleRowSurface()
        }
        .listStyle(.insetGrouped)
        .sampleListBackground()
        .navigationBarTitle("Appearance", displayMode: .inline)
        .accessibilityId("appearance-screen")
        .hostAppFooter()
    }
}

extension SampleAppearance {
    /// Forces this appearance on every window of the app, sheets and full screen covers included. The sample's
    /// colours resolve per trait, so the shell and the SDK both follow without being rebuilt.
    @MainActor
    func applyToWindows() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = userInterfaceStyle }
    }
}
