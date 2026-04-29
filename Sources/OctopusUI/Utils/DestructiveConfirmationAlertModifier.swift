//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// A view modifier that presents a destructive confirmation alert with iOS version compatibility.
/// Handles the `if #available(iOS 15.0, *)` branching internally, presenting a cancel button
/// and a destructive action button.
struct DestructiveConfirmationAlertModifier: ViewModifier {
    let title: LocalizedStringKey
    @Binding var isPresented: Bool
    let cancelLabel: LocalizedStringKey
    let destructiveLabel: LocalizedStringKey
    let action: () -> Void
    let message: LocalizedStringKey?

    func body(content: Content) -> some View {
        content.modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text(title, bundle: .module),
                    isPresented: $isPresented,
                    actions: {
                        Button(role: .cancel, action: {}) { Text(cancelLabel, bundle: .module) }
                        Button(role: .destructive, action: action) { Text(destructiveLabel, bundle: .module) }
                    },
                    message: {
                        if let message {
                            Text(message, bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $isPresented) {
                    if let message {
                        Alert(title: Text(title, bundle: .module),
                              message: Text(message, bundle: .module),
                              primaryButton: .default(Text(cancelLabel, bundle: .module)),
                              secondaryButton: .destructive(
                                Text(destructiveLabel, bundle: .module),
                                action: action))
                    } else {
                        Alert(title: Text(title, bundle: .module),
                              primaryButton: .default(Text(cancelLabel, bundle: .module)),
                              secondaryButton: .destructive(
                                Text(destructiveLabel, bundle: .module),
                                action: action))
                    }
                }
            }
        }
    }
}

extension View {
    func destructiveConfirmationAlert(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        cancelLabel: LocalizedStringKey = "Common.Cancel",
        destructiveLabel: LocalizedStringKey,
        action: @escaping () -> Void,
        message: LocalizedStringKey? = nil
    ) -> some View {
        modifier(DestructiveConfirmationAlertModifier(
            title: title, isPresented: isPresented,
            cancelLabel: cancelLabel, destructiveLabel: destructiveLabel,
            action: action, message: message))
    }
}
