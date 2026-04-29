//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// A menu button rendered in destructive (red) style.
///
/// On iOS 15+ uses `Button(role: .destructive)` so the system applies the standard
/// destructive treatment (red text inside `Menu`). On iOS 14 the `role:` API is
/// unavailable, so we fall back to an explicit red-tinted foreground on the same
/// button content — matching the existing iOS-14 destructive pattern in
/// `DestructiveConfirmationAlertModifier`.
struct DestructiveMenuButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        if #available(iOS 15.0, *) {
            Button(role: .destructive, action: action, label: label)
        } else {
            Button(action: action) {
                label()
                    .foregroundColor(.red)
            }
        }
    }
}
