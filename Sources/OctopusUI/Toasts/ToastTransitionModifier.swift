//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension AnyTransition {
    /// - Parameter fromTop: whether the toast slides in from the top of the screen, which is where the
    ///   error ones sit.
    static func toast(isManual: Bool, fromTop: Bool = false) -> AnyTransition {
        .modifier(
            active: ToastTransitionModifier(phase: .active, isManual: isManual, fromTop: fromTop),
            identity: ToastTransitionModifier(phase: .identity, isManual: isManual, fromTop: fromTop)
        )
    }
}

private struct ToastTransitionModifier: ViewModifier {
    enum Phase { case active, identity }
    let phase: Phase
    let isManual: Bool
    let fromTop: Bool

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
            guard phase == .active else { return 0 }
            return fromTop ? -200 : 200
        }
    }
}
