//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    /// `nil` when the string is empty or only made of whitespaces and newlines, the string itself otherwise.
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
