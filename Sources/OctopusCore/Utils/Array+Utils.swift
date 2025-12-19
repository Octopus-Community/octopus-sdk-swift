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

    /// Returns a sequence of pairs `(previous, current)` where `previous`
    /// is `nil` for the first element and the preceding element otherwise.
    func withPrevious() -> AnySequence<(previous: Element?, current: Element)> {
        AnySequence { () -> AnyIterator<(previous: Element?, current: Element)> in
            var iterator = self.makeIterator()
            var previous: Element? = nil

            return AnyIterator {
                guard let current = iterator.next() else {
                    return nil
                }
                defer { previous = current }
                return (previous, current)
            }
        }
    }
}
