//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CloseButton: View {
    @Environment(\.octopusTheme) private var theme

    let action: () -> Void

    var body: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Button(action: action) {
                IconImage(theme.assets.icons.common.close)
                    .font(theme.fonts.navBarItem)
                    .contentShape(Rectangle())
                    .accessibilityLabelInBundle("Common.Close")
            }
        } else {
            Button(action: action) {
                IconImage(theme.assets.icons.common.close)
                    .font(theme.fonts.navBarItem)
                    .contentShape(Rectangle())
                    .accessibilityLabelInBundle("Common.Close")
            }
        }
#else
        Button(action: action) {
            IconImage(theme.assets.icons.common.close)
                .font(theme.fonts.navBarItem)
                .contentShape(Rectangle())
                .accessibilityLabelInBundle("Common.Close")
        }
#endif
    }
}
