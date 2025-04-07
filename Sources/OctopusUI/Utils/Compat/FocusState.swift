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

@available(iOS 15.0, *)
private struct TextFieldFocusedWithIdentifier<Focusable: Hashable>: ViewModifier {

    private let focusIdentifier: Focusable
    @FocusState private var focus: Focusable?
    @Binding private var externalFocus: Focusable?

    init(focusIdentifier: Focusable, externalFocus: Binding<Focusable?>) {
        self.focusIdentifier = focusIdentifier
        self._externalFocus = externalFocus
        self.focus = externalFocus.wrappedValue
    }

    func body(content: Content) -> some View {
        content
            .focused($focus, equals: focusIdentifier)
            .onChange(of: externalFocus) { newValue in
                focus = newValue
            }
            .onChange(of: focus) { newValue in
                if let newValue {
                    externalFocus = newValue
                }
            }
            .onAppear {
                focus = externalFocus
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

    @ViewBuilder
    func focused<Focusable: Hashable>(id: Focusable, _ value: Binding<Focusable?>) -> some View {
        if #available(iOS 15.0, *) {
            self.modifier(TextFieldFocusedWithIdentifier(focusIdentifier: id, externalFocus: value))
        } else {
            self
        }
    }
}
