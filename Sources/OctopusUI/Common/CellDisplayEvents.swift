//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

struct CellDisplayEvents: Equatable {
    let onAppear: () -> Void
    let onDisappear: () -> Void

    static func == (lhs: CellDisplayEvents, rhs: CellDisplayEvents) -> Bool {
        true
    }
}
