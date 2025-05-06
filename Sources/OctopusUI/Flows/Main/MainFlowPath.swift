//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine

class MainFlowPath: ObservableObject {
    @Published var path: [MainFlowScreen] = []

    /// Whether the path should not be changed
    @Published var isLocked: Bool = false
}
