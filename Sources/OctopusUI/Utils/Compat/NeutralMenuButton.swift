//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// A non-destructive menu button whose icon keeps the color of its title.
///
/// Inside a `Menu`, the system draws the title of a plain item in the label color, but its
/// template icon in the inherited tint. When an ancestor sets `.tint(_:)` or `.accentColor(_:)` —
/// as a host app commonly does on its root view, and as the SDK does with the theme's primary
/// color — the icon then shows in that color next to a white (or black) title. Pinning the tint to
/// the label color keeps icon and title the same color, in light and dark mode, the way
/// `DestructiveMenuButton` keeps a destructive icon red.
struct NeutralMenuButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        if #available(iOS 15.0, *) {
            Button(action: action, label: label)
                .tint(Color(UIColor.label))
        } else {
            Button(action: action) {
                label()
                    .foregroundColor(Color(UIColor.label))
            }
        }
    }
}
