//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

private struct CommunityNavigationBarBackgroundModifier: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    let glassEffectAvailable: Bool

    func body(content: Content) -> some View {
        content
            .modify {
                // Without the glass effect, the bar the system draws once the content scrolls under it is the
                // system background (white in light mode), which stands out over a community background.
                // With the glass effect, the bar keeps its default translucent behavior.
                if #available(iOS 16.0, *), !glassEffectAvailable {
                    $0.toolbarBackground(theme.colors.background, for: .navigationBar)
                } else { $0 }
            }
    }
}

extension View {
    /// Draws the navigation bar of this screen in the community background, as the screens built on
    /// `zoomableImageContainer` already do through `forceColorScheme`.
    ///
    /// - Parameter glassEffectAvailable: whether the app draws with the glass effect; only tests pass it.
    func communityNavigationBarBackground(glassEffectAvailable: Bool = GlassEffect.isAvailable) -> some View {
        modifier(CommunityNavigationBarBackgroundModifier(glassEffectAvailable: glassEffectAvailable))
    }
}
