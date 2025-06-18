//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: true
        case .failure: false
        }
    }

    var isFailure: Bool {
        !isSuccess
    }
}
