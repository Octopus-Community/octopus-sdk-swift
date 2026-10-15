//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Puts host screens on the sample's own surfaces — the Android tokens, navy in dark mode — instead of the
/// system grouped grays (`#F2F2F7` / `#000000` / `#1C1C1E`).
///
/// The `List` modifiers are iOS 16+ only: `scrollContentBackground(.hidden)` is what lets a `List` show a custom
/// background, so iOS 15 keeps the native grays for both the list and its rows and the two never mismatch.
/// The screen and card modifiers draw plain shapes and apply on every OS version.
extension View {
    /// The list's background, behind the rows and under the floating tab bar.
    @ViewBuilder
    func sampleListBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
                .background(SampleTokens.Colors.background.ignoresSafeArea())
        } else {
            self
        }
    }

    /// The background of the rows this modifier is applied to (a section, or a group of sections).
    @ViewBuilder
    func sampleRowSurface() -> some View {
        if #available(iOS 16.0, *) {
            listRowBackground(SampleTokens.Colors.surface)
        } else {
            self
        }
    }

    /// The background of a host screen that is not a `List` (a stack or a scroll view of cards), on every
    /// OS version: unlike a `List`, such a screen has no system background to hide first.
    func sampleScreenBackground() -> some View {
        background(SampleTokens.Colors.background.ignoresSafeArea())
    }

    /// A card on a host screen: the raised surface, a 1 pt hairline and the large radius, as the sample's
    /// list rows. Replaces the system `secondarySystemBackground` fill, which is a gray in light mode and
    /// near-black in dark mode, off the sample palette in both.
    func sampleCardSurface(cornerRadius: CGFloat = SampleTokens.Radius.large) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(SampleTokens.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(SampleTokens.Colors.hairline, lineWidth: 1)
        )
    }
}
