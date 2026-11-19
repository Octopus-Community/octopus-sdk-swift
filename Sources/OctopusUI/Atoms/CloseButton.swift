//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CloseButton: View {
    @Environment(\.octopusTheme) private var theme

    let action: () -> Void
    /// The minimum side of the tappable area, for a button that is not in a navigation bar, which would extend it.
    var minimumTapSide: CGFloat?

    var body: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), GlassEffect.isAvailable {
            Button(action: action) {
                label
            }
        } else {
            Button(action: action) {
                label
            }
        }
#else
        Button(action: action) {
            label
        }
#endif
    }

    private var label: some View {
        IconImage(theme.assets.icons.common.close)
            .font(theme.fonts.navBarItem)
            .modify {
                if let minimumTapSide {
                    $0.frame(minWidth: minimumTapSide, minHeight: minimumTapSide)
                } else {
                    $0
                }
            }
            .contentShape(Rectangle())
            .accessibilityLabelInBundle("Common.Close")
    }
}
