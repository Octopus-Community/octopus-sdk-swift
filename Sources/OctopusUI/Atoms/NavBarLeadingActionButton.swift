//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Renders the host-driven leading nav-bar item (`OctopusNavBarLeadingAction`) using the SDK's native
/// `CloseButton` / `BackButton`, so it matches the styling of the SDK's own nav-bar items.
///
/// Screens with an unsaved-changes guard can pass a custom `onTap` (e.g. one that shows a confirmation
/// alert first); by default the action's own closure is used.
struct NavBarLeadingActionButton: View {
    private let action: OctopusNavBarLeadingAction
    private let onTap: () -> Void

    init(_ action: OctopusNavBarLeadingAction, onTap: (() -> Void)? = nil) {
        self.action = action
        self.onTap = onTap ?? action.onTap
    }

    var body: some View {
        switch action {
        case .close:
            CloseButton(action: onTap)
        case .back:
            BackButton(action: onTap)
        }
    }
}
