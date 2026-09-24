//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }

    /// Sets an accessibility identifier (used as a QA test id).
    ///
    /// On iOS 13 `accessibilityIdentifier` does not exist, but its predecessor
    /// `accessibility(identifier:)` does — so the identifier is preserved across the whole supported
    /// range rather than silently dropped on the minimum deployment target, which would make every QA
    /// test id unresolvable there.
    @ViewBuilder
    func accessibilityId(_ identifier: String) -> some View {
        if #available(iOS 14.0, *) {
            self.accessibilityIdentifier(identifier)
        } else {
            self.accessibility(identifier: identifier)
        }
    }

    /// Sets an accessibility label, using the iOS 13 predecessor below iOS 14.
    ///
    /// Named `…Compat` rather than shadowing SwiftUI's own `accessibilityLabel`, which would make the
    /// iOS 14+ branch recurse into itself.
    @ViewBuilder
    func accessibilityLabelCompat(_ label: String) -> some View {
        if #available(iOS 14.0, *) {
            self.accessibilityLabel(label)
        } else {
            self.accessibility(label: Text(label))
        }
    }
}
