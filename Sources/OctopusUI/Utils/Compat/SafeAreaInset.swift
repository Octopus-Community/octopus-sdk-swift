//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

extension Compat {
    /// What `safeAreaInsetCompat` shows below iOS 15, where there is no safe area inset.
    enum SafeAreaInsetFallback {
        /// The view alone: the inset content is dropped.
        case dropContent
        /// The view and the inset content stacked on the inset's edge: the content is laid under the view for the
        /// bottom edge and above it for the top edge, instead of over it.
        case stackContent
    }
}

extension View {
    /// `safeAreaInset(edge:alignment:spacing:content:)` on iOS 15+. Below, `fallback` tells what is shown instead.
    @ViewBuilder
    func safeAreaInsetCompat<V>(edge: Compat.VerticalEdge, alignment: HorizontalAlignment = .center,
                                spacing: CGFloat? = nil, fallback: Compat.SafeAreaInsetFallback = .dropContent,
                                @ViewBuilder content: () -> V) -> some View where V: View {
        if #available(iOS 15.0, *) {
            self.safeAreaInset(edge: edge.usableValue, alignment: alignment, spacing: spacing, content: content)
        } else {
            switch fallback {
            case .dropContent:
                self
            case .stackContent:
                // Built as `TupleView`s: a two-view builder block makes a `TupleContent`, a view from iOS 26 only.
                VStack(alignment: alignment, spacing: spacing) {
                    switch edge {
                    case .top: TupleView((content(), self))
                    case .bottom: TupleView((self, content()))
                    }
                }
            }
        }
    }
}
