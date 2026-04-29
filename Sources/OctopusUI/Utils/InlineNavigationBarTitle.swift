//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

private enum InlineNavigationBarTitle {
    /// Font used by inline navigation bar titles.
    ///
    /// When rendering a title inside `ToolbarItem(placement: .principal)`, the
    /// system inline navigation title styling is NOT inherited (unlike
    /// `.navigationBarTitle(_:displayMode: .inline)` which renders natively).
    /// To keep the two code paths visually consistent — including when the
    /// host app has customized the nav bar appearance — we resolve the font
    /// from `UINavigationBar.appearance()` at read time, falling back to the
    /// system default (`.headline`) if nothing has been customized.
    ///
    /// Note: this reads from the global appearance proxy. Per-instance
    /// customizations made directly on a `UINavigationController`'s
    /// `navigationBar` (not via the global proxy) will not be picked up.
    @MainActor
    static var font: Font {
        let uiFont: UIFont = {
            // Modern proxy (iOS 13+): UINavigationBarAppearance tiers.
            if let font = UINavigationBar.appearance().standardAppearance
                .titleTextAttributes[.font] as? UIFont {
                return font
            }
            // Legacy proxy: still used by some host apps.
            if let font = UINavigationBar.appearance().titleTextAttributes?[.font] as? UIFont {
                return font
            }
            // System default for inline navigation titles.
            return .preferredFont(forTextStyle: .headline)
        }()
        return Font(uiFont)
    }
}

extension View {
    /// Applies the font used by inline navigation bar titles, honoring any
    /// `UINavigationBar.appearance()` customization set by the host app.
    ///
    /// Use this when rendering a title-like `Text` inside
    /// `ToolbarItem(placement: .principal)` so it matches the look of a
    /// natively rendered `.navigationBarTitle(_:displayMode: .inline)`.
    func inlineNavigationBarTitleFont() -> some View {
        font(InlineNavigationBarTitle.font)
    }
}
