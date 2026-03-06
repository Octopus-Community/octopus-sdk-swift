//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// A VStack that is lazy by default, until preventLaziness is set to true. After that, it is a VStack.
/// This component is here because there a UI glitches (even crashes) when we scroll to a bottom of a scroll view that
/// contains a LazyVStack and the views inside this LazyVStack do not have the same height.
struct LazyIfPossibleVStack<Content: View>: View {
    let spacing: CGFloat?
    let preventLaziness: Bool
    @ViewBuilder let content: Content

    @State private var isLazy: Bool

    init(spacing: CGFloat? = nil, preventLaziness: Bool, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.preventLaziness = preventLaziness
        self.content = content()
        _isLazy = State(initialValue: !preventLaziness)
    }

    var body: some View {
        Group {
            if isLazy {
                Compat.LazyVStack(spacing: spacing) {
                    content
                }
            } else {
                VStack(spacing: spacing) {
                    content
                }
            }
        }
        .onValueChanged(of: preventLaziness) { preventLaziness in
            if preventLaziness {
                isLazy = false
            }
        }
    }
}
