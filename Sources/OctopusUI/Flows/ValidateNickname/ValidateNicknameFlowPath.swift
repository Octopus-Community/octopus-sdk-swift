//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine

class ValidateNicknameFlowPath: ObservableObject {
    @Published var path: [ValidateNicknameFlowScreen] = []

    /// Whether the path should not be changed
    @Published var isLocked: Bool = false
}
