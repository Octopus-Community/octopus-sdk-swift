//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

extension Array {
    func removingDuplicates<T: Hashable>(by keySelector: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return self.filter { element in
            let key = keySelector(element)
            return seen.insert(key).inserted
        }
    }

    var nilIfEmpty: Array? {
        isEmpty ? nil : self
    }
}
