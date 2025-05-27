//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

struct InsetableMainNavigationView: ViewModifier {
    let bottomSafeAreaInset: CGFloat

    @State private var keyboardHeight = CGFloat.zero
    @State private var bottomInset: CGFloat

    init(bottomSafeAreaInset: CGFloat) {
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self._bottomInset = .init(initialValue: bottomSafeAreaInset)
    }

    func body(content: Content) -> some View {
        content
            .keyboardHeight($keyboardHeight)
            .safeAreaInsetCompat(edge: .bottom) {
                Spacer().frame(height: bottomInset)
            }
            .onValueChanged(of: keyboardHeight) { keyboardHeight in
                withAnimation {
                    bottomInset = keyboardHeight <= bottomSafeAreaInset ? bottomSafeAreaInset : 0
                }
            }
            .onValueChanged(of: bottomSafeAreaInset) { bottomSafeAreaInset in
                withAnimation {
                    bottomInset = keyboardHeight <= bottomSafeAreaInset ? bottomSafeAreaInset : 0
                }
            }
            .onAppear {
                withAnimation {
                    bottomInset = keyboardHeight <= bottomSafeAreaInset ? bottomSafeAreaInset : 0
                }
            }
    }
}

extension View {
    /// Apply a safe area inset to this view.
    /// When the keyboard is displayed, remove the inset
    /// - Parameter bottomSafeAreaInset: the bottom safe area to set
    @ViewBuilder
    func insetableMainNavigationView(
        bottomSafeAreaInset: CGFloat) -> some View {
            if bottomSafeAreaInset > 0 {
                self.modifier(
                    InsetableMainNavigationView(
                        bottomSafeAreaInset: bottomSafeAreaInset
                    )
                )
            } else {
                self
            }
    }
}
