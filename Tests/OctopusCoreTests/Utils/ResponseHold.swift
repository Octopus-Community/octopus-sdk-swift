//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Holds a mocked response until the test releases it, and tells the test when the call has reached it.
actor ResponseHold {
    private(set) var isReached = false
    private var isReleased = false
    private var releaseWaiters = [CheckedContinuation<Void, Never>]()

    /// Called by the mock: waits for `release()`.
    func pass() async {
        isReached = true
        guard !isReleased else { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    /// Waits for a call to reach the hold, and records a failure if none does within `timeout` seconds.
    nonisolated func waitUntilReached(timeout: TimeInterval = 5) async throws {
        try await expectWithTimeout(timeout: timeout) { await self.isReached }
    }

    func release() {
        isReleased = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters = []
    }
}
