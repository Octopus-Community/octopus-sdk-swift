//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

extension View {
    @ViewBuilder
    func safeAreaInsetCompat<V>(edge: Compat.VerticalEdge, alignment: HorizontalAlignment = .center,
                                spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View where V : View {
        if #available(iOS 15.0, *) {
            self.safeAreaInset(edge: edge.usableValue, alignment: alignment, spacing: spacing, content: content)
        } else {
            self
        }
    }
}
