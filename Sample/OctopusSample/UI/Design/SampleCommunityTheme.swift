//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit
import Octopus
import OctopusUI

/// The SDK theme behind Settings › Appearance › Theme preset, the iOS twin of the Android sample's
/// `CommunityTheme`.
///
/// "Octopus navy" is the sample's own brand, built from `SampleTokens`, so the community and the host screens
/// read as one app: navy in light, the lighter accent in dark (navy has no contrast on a dark background).
/// "SDK default" hands the SDK no theme at all, which is what a fresh integration looks like.
enum SampleCommunityTheme {
    static let navy = OctopusTheme(
        colors: .init(
            primarySet: OctopusTheme.Colors.ColorSet(
                main: dynamic(light: SampleTokens.Colors.navy, dark: SampleTokens.Colors.accentText),
                lowContrast: SampleTokens.Colors.accentTint,
                highContrast: SampleTokens.Colors.accent),
            onPrimary: dynamic(light: SampleTokens.Colors.onNavy, dark: SampleTokens.Colors.background)))

    /// One colour per interface style, from two token colours that already resolve per trait.
    private static func dynamic(light: Color, dark: Color) -> Color {
        let lightColor = UIColor(light)
        let darkColor = UIColor(dark)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? darkColor.resolvedColor(with: traits)
                : lightColor.resolvedColor(with: traits)
        })
    }
}

extension View {
    /// Hands the SDK screens below the theme of the current preset, and follows a change at once.
    func sampleCommunityTheme() -> some View {
        modifier(SampleCommunityThemeModifier())
    }
}

private struct SampleCommunityThemeModifier: ViewModifier {
    @ObservedObject private var appearance = SampleAppearanceStore.instance

    func body(content: Content) -> some View {
        switch appearance.themePreset {
        case .octopusNavy:
            content.environment(\.octopusTheme, SampleCommunityTheme.navy)
        case .sdkDefault:
            content
        }
    }
}
