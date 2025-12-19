//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Compat {
    @available(iOS 15.0, *)
    struct AccessibilityFocusModifier: ViewModifier {
        @Binding var focus: Bool
        @AccessibilityFocusState private var focused: Bool

        func body(content: Content) -> some View {
            content
                .accessibilityFocused($focused)
                .onValueChanged(of: focus, initial: true) {
                    focused = $0
                }
        }
    }

    @available(iOS 15.0, *)
    struct AccessibilityFocusOnAppearModifier: ViewModifier {
        @State private var focused = false

        func body(content: Content) -> some View {
            content
                .accessibilityFocusedCompat($focused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        focused = true
                    }
                }
        }
    }

}

extension View {
    @ViewBuilder
    func accessibilityFocusedCompat(_ focus: Binding<Bool>) -> some View {
        if #available(iOS 15.0, *) {
            self.modifier(Compat.AccessibilityFocusModifier(focus: focus))
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func accessibilityFocusOnAppear() -> some View {
        if #available(iOS 15.0, *) {
            self.modifier(Compat.AccessibilityFocusOnAppearModifier())
        } else {
            self
        }
    }
}
