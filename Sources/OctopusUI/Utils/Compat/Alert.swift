//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    nonisolated func compatAlert<A, M, T>(
        _ title: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?,
        @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View where A: View, M: View {
            if #available(iOS 15.0, *) {
                self.alert(
                    Text(title, bundle: .module),
                    isPresented: isPresented,
                    presenting: data,
                    actions: actions,
                    message: message)
            } else {
                self.alert(isPresented: isPresented, content: {
                    Alert(
                        title: Text(title, bundle: .module),
                        message: data.map { message($0) } as? Text ?? Text(verbatim: "")
                    )
                })
            }
        }

    /// An alert offering two buttons, each with its own action, on every iOS version: below iOS 15, the
    /// `compatAlert` above drops its action buttons and only offers OK.
    ///
    /// - Parameters:
    ///   - title: the localization key of the title, looked up in the SDK's bundle.
    ///   - isPresented: whether the alert is shown. Either button dismisses it.
    ///   - message: the text under the title, if any.
    ///   - primaryButton: the localization key of the first button, looked up in the SDK's bundle.
    ///   - primaryAction: what the first button does, besides dismissing the alert.
    ///   - secondaryButton: the localization key of the second button, looked up in the SDK's bundle.
    ///   - secondaryAction: what the second button does, besides dismissing the alert.
    @ViewBuilder
    nonisolated func compatAlert(
        _ title: LocalizedStringKey, isPresented: Binding<Bool>, message: Text?,
        primaryButton: LocalizedStringKey, primaryAction: @escaping () -> Void,
        secondaryButton: LocalizedStringKey, secondaryAction: @escaping () -> Void) -> some View {
            if #available(iOS 15.0, *) {
                self.alert(
                    Text(title, bundle: .module),
                    isPresented: isPresented,
                    actions: {
                        Button(action: primaryAction) { Text(primaryButton, bundle: .module) }
                        Button(action: secondaryAction) { Text(secondaryButton, bundle: .module) }
                    },
                    message: { if let message { message } })
            } else {
                self.alert(isPresented: isPresented, content: {
                    Alert(
                        title: Text(title, bundle: .module),
                        message: message,
                        primaryButton: .default(Text(primaryButton, bundle: .module), action: primaryAction),
                        secondaryButton: .default(Text(secondaryButton, bundle: .module), action: secondaryAction))
                })
            }
        }
}
