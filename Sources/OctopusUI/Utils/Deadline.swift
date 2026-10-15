//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Runs `operation` and returns its result, or `nil` once `nanoseconds` have passed without one.
///
/// It returns at the deadline even when the operation does not, which a task group cannot do: a group waits for
/// its cancelled children, and a call stuck on a dead connection may never notice the cancellation. The
/// operation is cancelled at the deadline and its late result, value or error, is dropped.
@MainActor
func withDeadline<T: Sendable>(nanoseconds: UInt64,
                               operation: @escaping @MainActor () async throws -> T) async throws -> T? {
    let race = DeadlineRace()
    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T?, Error>) in
        let work = Task { @MainActor in
            do {
                let value = try await operation()
                if race.finish() { continuation.resume(returning: value) }
            } catch {
                if race.finish() { continuation.resume(throwing: error) }
            }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard race.finish() else { return }
            work.cancel()
            continuation.resume(returning: nil)
        }
    }
}

/// Lets only the first of the operation and the deadline resume the continuation.
@MainActor
private final class DeadlineRace {
    private var isFinished = false

    func finish() -> Bool {
        guard !isFinished else { return false }
        isFinished = true
        return true
    }
}
