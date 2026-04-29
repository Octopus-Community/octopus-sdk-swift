//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI

/// A view modifier that encapsulates the common error alert pattern used throughout the app.
/// It manages the `displayError` and `displayableError` state internally, subscribes to a
/// publisher of `DisplayableString?`, and presents a `compatAlert` when an error is emitted.
struct ErrorAlertModifier<P: Publisher>: ViewModifier where P.Output == DisplayableString?, P.Failure == Never {
    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    let errorPublisher: P
    let onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .compatAlert(
                "Common.Error",
                isPresented: $displayError,
                presenting: displayableError,
                actions: { _ in },
                message: { error in error.textView })
            .onReceive(errorPublisher) { error in
                guard let error else { return }
                displayableError = error
                displayError = true
            }
            .onValueChanged(of: displayError) {
                if !$0 { onDismiss?() }
            }
    }
}

extension View {
    func errorAlert<P: Publisher>(
        _ errorPublisher: P,
        onDismiss: (() -> Void)? = nil
    ) -> some View where P.Output == DisplayableString?, P.Failure == Never {
        modifier(ErrorAlertModifier(errorPublisher: errorPublisher, onDismiss: onDismiss))
    }
}
