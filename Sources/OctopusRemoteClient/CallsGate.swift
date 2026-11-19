//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Whether calls to the server are allowed. Shared by every service client of a `GrpcClient`, so that blocking it
/// blocks every call at once.
///
/// Locked: it is set from the main queue when the community closes or reopens, and read from whichever task sends a
/// call.
final class CallsGate: @unchecked Sendable {
    private let lock = NSLock()
    private var _isBlocked = false

    var isBlocked: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isBlocked
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isBlocked = newValue
        }
    }
}

/// The error of a call that was not sent because calls to the server are blocked.
public struct CallsBlockedError: Error {}
