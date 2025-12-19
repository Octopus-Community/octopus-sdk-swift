//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Compat {
    /// A LazyVStack that fallbacks on a normal VStack
    struct LazyVStack<Content: View>: View {
        var spacing: CGFloat?
        @ViewBuilder let content: Content

        @ViewBuilder
        var body: some View {
            if #available(iOS 14.0, *) {
                SwiftUI.LazyVStack(spacing: spacing) {
                    content
                }
            } else {
                VStack {
                    content
                }
            }
        }
    }

    /// A LazyHStack that fallbacks on a normal HStack
    struct LazyHStack<Content: View>: View {
        @ViewBuilder let content: Content

        @ViewBuilder
        var body: some View {
            if #available(iOS 14.0, *) {
                SwiftUI.LazyHStack {
                    content
                }
            } else {
                HStack {
                    content
                }
            }
        }
    }
}
