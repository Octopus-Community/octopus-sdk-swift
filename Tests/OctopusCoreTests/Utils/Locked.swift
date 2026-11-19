//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Thread-safe box, for a value that a closure writes on another thread than the test body reading it: a sink of a
/// publisher delivering on the main queue (or on whichever thread saved), while an `async` test body runs on the
/// cooperative pool. A plain captured `var` races there, and a value holding references can be released twice.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedValue = newValue
        }
    }

    init(_ value: Value) {
        storedValue = value
    }

    /// Changes the value under a single lock, where `value.append(…)` would read and write it under two.
    func mutate(_ change: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        change(&storedValue)
    }
}
