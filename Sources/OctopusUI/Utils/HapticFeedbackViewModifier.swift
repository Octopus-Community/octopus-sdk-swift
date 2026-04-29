//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import OctopusCore

extension View {
    func hapticFeedback<T>(trigger: T, _ shouldFeedback: @escaping (_ oldValue: T, _ newValue: T) -> Bool) -> some View where T: Equatable {
        self.modify {
            if #available(iOS 17.0, *) {
                $0.sensoryFeedback(trigger: trigger) {
                    guard shouldFeedback($0, $1) else { return nil }
                    return .impact(flexibility: .soft)
                }
            } else { $0 }
        }
    }
}
