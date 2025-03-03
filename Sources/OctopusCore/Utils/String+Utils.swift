//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
