//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// The box the profile / activity tab rows are built on.
///
/// The inline selector (``CustomSegmentedControl``, underline style) and the pinned header
/// (``ProfileStickyTabsHeader``, glass pills) are two different renderings of the *same* row: same
/// row padding, same inter-tab spacing, same per-tab padding, same font metrics. Sharing the box is
/// what makes the two rows land on the exact same positions, so the pinned pills sit right on top of
/// the tabs they replace when the header sticks.
///
/// Tabs divide the row evenly when it has width to spare, and size to their label when it overflows
/// (the row then scrolls). Either way the selected-tab underline spans its tab edge to edge and the
/// label is centered on it by construction.
enum ProfileTabsLayout {
    /// Horizontal padding of the row, per the Figma tab-bar component.
    static let rowHorizontalPadding: CGFloat = 16
    /// Spacing between two tabs, per the Figma tab-bar component.
    static let interTabSpacing: CGFloat = 8
    /// Horizontal padding inside a tab, between its label and its own edges.
    static let tabHorizontalPadding: CGFloat = 16
    /// Vertical padding inside a tab.
    static let tabVerticalPadding: CGFloat = 10
    /// Thickness of the selected-tab underline.
    static let underlineHeight: CGFloat = 2

    /// The cross-fade between the inline row and the pinned pills that replace it.
    static let pinnedHeaderAnimation: Animation = .easeInOut(duration: 0.2)

    /// The `offset(x:)` that moves the selected-tab underline from the row's horizontal centre — where
    /// a `.center`-aligned child starts, in both layout directions — onto its tab.
    ///
    /// The two inputs do not agree on direction: `GeometryProxy.frame(in:)` reports physical
    /// coordinates (x grows rightwards whatever the language), while `offset(x:)` is mirrored in RTL.
    /// So the physical delta has to be negated there, or the underline lands on the tab symmetric to
    /// the selected one.
    ///
    /// - Parameters:
    ///   - tabMidX: the selected tab's horizontal centre, in the row's coordinate space.
    ///   - rowWidth: the row's full width.
    ///   - layoutDirection: the environment's layout direction.
    static func underlineOffset(tabMidX: CGFloat, rowWidth: CGFloat,
                                layoutDirection: LayoutDirection) -> CGFloat {
        let physicalOffset = tabMidX - rowWidth / 2
        return layoutDirection == .rightToLeft ? -physicalOffset : physicalOffset
    }
}

extension View {
    /// Fades the inline tab row out while the pinned pills stand in for it.
    ///
    /// The profile scroll views bleed under the translucent navigation bar, so the inline row stays
    /// visible *through* the pinned header instead of being clipped by it — the two rows would
    /// otherwise show at once, one blurred behind the other. Hiding it also hands the taps to the
    /// pills, which are the row the user can actually see.
    ///
    /// Opacity rather than removal, so the row keeps its place in the scroll content and the
    /// `GeometryReader` that drives `pinnedHeaderShows` keeps reporting.
    func hiddenWhilePinnedHeaderShows(_ pinnedHeaderShows: Bool) -> some View {
        opacity(pinnedHeaderShows ? 0 : 1)
            .allowsHitTesting(!pinnedHeaderShows)
    }
}
