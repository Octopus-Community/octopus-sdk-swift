//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 15.0, *)
private struct TextFieldFocused: ViewModifier {

    @FocusState private var focused: Bool
    @Binding private var externalFocused: Bool

    init(externalFocused: Binding<Bool>) {
        self._externalFocused = externalFocused
        self.focused = externalFocused.wrappedValue
    }

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onChange(of: externalFocused) { newValue in
                focused = newValue
            }
            .onChange(of: focused) { newValue in
                externalFocused = newValue
            }
            .onAppear {
                if externalFocused {
                    focused = true
                }
            }
    }
}

extension View {
    @ViewBuilder
    func focused(_ value: Binding<Bool>) -> some View {
        if #available(iOS 15.0, *) {
            self.modifier(TextFieldFocused(externalFocused: value))
        } else {
            self
        }
    }
}
