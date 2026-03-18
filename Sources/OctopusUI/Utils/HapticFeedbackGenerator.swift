//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

enum HapticFeedback {
    @MainActor
    static func play() {
        let impactHeavy = UIImpactFeedbackGenerator(style: .soft)
        impactHeavy.impactOccurred()
    }
}
