//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    func refreshVoiceOverFocus(on element: Any?) {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)

            DispatchQueue.main.async {
                UIAccessibility.post(notification: .layoutChanged, argument: element)
            }
        }
}
