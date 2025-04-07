//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    func disableAnimation() -> some View {
        self
            .transaction { $0.animation = nil }
    }
}
