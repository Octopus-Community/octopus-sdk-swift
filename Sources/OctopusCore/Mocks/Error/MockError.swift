//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

struct MockError: LocalizedError {
    let errorDescription: String?

    init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}
