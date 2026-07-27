//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// Layout constants and helpers for constraining the scrollable content column on large screens
/// (iPad, iPhone landscape) so line lengths stay readable instead of stretching edge to edge (OCT-1532).
enum OctopusContentLayout {
    /// Max width of the scrollable content column, by device idiom.
    /// - iPhone (and any non-pad idiom): 570pt
    /// - iPad: 1106pt
    ///
    /// Exposed with an explicit `idiom` parameter so the value is unit-testable without a live device.
    static func maxContentWidth(for idiom: UIUserInterfaceIdiom) -> CGFloat {
        idiom == .pad ? 1106 : 570
    }

    /// Max width of the scrollable content column for the current device.
    static var maxContentWidth: CGFloat {
        maxContentWidth(for: UIDevice.current.userInterfaceIdiom)
    }
}

private struct ConstrainedContentColumnModifier: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    /// When `false`, the capped column is left transparent instead of getting an opaque background —
    /// used by the profile's sticky header so a translucent (glass) background can show through.
    let opaqueBackground: Bool

    func body(content: Content) -> some View {
        content
            // Cap the column width…
            .frame(maxWidth: OctopusContentLayout.maxContentWidth)
            // …give it an opaque background so it reads as a card over the margin background…
            .modify {
                if opaqueBackground {
                    $0.background(theme.colors.background)
                } else {
                    $0
                }
            }
            // …then expand to the full available width so the capped column is centered, leaving
            // the remaining space as side margins on large screens.
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Constrains the receiver (a scrollable content column) to ``OctopusContentLayout/maxContentWidth``
    /// and centers it horizontally. On screens narrower than the cap (iPhone portrait) this is a no-op;
    /// on wider screens (iPad, landscape) the extra space becomes side margins.
    ///
    /// Apply this to the content **inside** a scroll view, before any width is read down to the cells,
    /// so the cells size themselves to the constrained width (e.g. media sizing).
    ///
    /// - Parameter opaqueBackground: give the capped column an opaque background so it reads as a card
    ///   over the margin background. Pass `false` when a translucent background must show through
    ///   (e.g. the profile sticky header's glass on iOS 26).
    func constrainedContentColumn(opaqueBackground: Bool = true) -> some View {
        modifier(ConstrainedContentColumnModifier(opaqueBackground: opaqueBackground))
    }
}

private struct LargeScreenMarginBackgroundModifier: ViewModifier {
    @Environment(\.octopusTheme) private var theme

    func body(content: Content) -> some View {
        // The large-screen side margins use the community background color (default: the standard
        // system background), so the capped content column blends into a uniform background instead
        // of reading as a card. Fill all safe areas — including the top — so a custom community
        // background blends behind the (translucent / scroll-edge) navigation bar instead of leaving
        // a system-colored strip there. With the default (systemBackground) this matches the window
        // background, so existing integrators see no change; only a customized background now extends
        // behind the bar (OCT-1532 originally excluded the top for the white default; the themeable
        // background makes covering it the correct behavior).
        content.background(
            theme.colors.background
                .edgesIgnoringSafeArea(.all)
        )
    }
}

extension View {
    /// Fills the screen behind a content view — the side margins left by ``constrainedContentColumn()``
    /// on large screens (iPad, landscape) and the area behind any bottom bar — with the standard
    /// background (white in light mode), so nothing shows through in those regions (OCT-1532).
    func largeScreenMarginBackground() -> some View {
        modifier(LargeScreenMarginBackgroundModifier())
    }
}
