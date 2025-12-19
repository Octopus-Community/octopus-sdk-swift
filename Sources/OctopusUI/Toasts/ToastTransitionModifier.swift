//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension AnyTransition {
    static func toast(isManual: Bool) -> AnyTransition {
        .modifier(
            active: ToastTransitionModifier(phase: .active, isManual: isManual),
            identity: ToastTransitionModifier(phase: .identity, isManual: isManual)
        )
    }
}

private struct ToastTransitionModifier: ViewModifier {
    enum Phase { case active, identity }
    let phase: Phase
    let isManual: Bool

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(y: offsetY)
    }

    private var opacity: Double {
        switch phase {
        case .identity: return 1
        case .active: return 0
        }
    }

    private var offsetY: CGFloat {
        if isManual {
            return 0 // fade only
        } else {
            return phase == .active ? 200 : 0 // slide from bottom
        }
    }
}
