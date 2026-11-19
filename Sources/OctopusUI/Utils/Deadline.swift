//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Runs `operation` and returns its result, or `nil` once `nanoseconds` have passed without one.
///
/// It returns at the deadline even when the operation does not, which a task group cannot do: a group waits for
/// its cancelled children, and a call stuck on a dead connection may never notice the cancellation. The
/// operation is cancelled at the deadline and its late result, value or error, is dropped.
///
/// Cancelling the calling task does the same at once: the operation is cancelled, the call throws a
/// `CancellationError` without waiting for it, and its late result is dropped.
@MainActor
func withDeadline<T: Sendable>(nanoseconds: UInt64,
                               operation: @escaping @MainActor () async throws -> T) async throws -> T? {
    let race = DeadlineRace<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T?, Error>) in
            race.start(continuation, work: Task { @MainActor in
                do {
                    race.finish(.success(try await operation()))
                } catch {
                    race.finish(.failure(error))
                }
            })
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: nanoseconds)
                race.giveUp(.success(nil))
            }
        }
    } onCancel: {
        // Runs after the continuation is set: it is set synchronously on the main actor, which this waits for.
        Task { @MainActor in race.giveUp(.failure(CancellationError())) }
    }
}

/// Lets only the first of the operation, the deadline and the caller's cancellation resume the continuation.
@MainActor
private final class DeadlineRace<T: Sendable> {
    private var continuation: CheckedContinuation<T?, Error>?
    private var work: Task<Void, Never>?

    func start(_ continuation: CheckedContinuation<T?, Error>, work: Task<Void, Never>) {
        self.continuation = continuation
        self.work = work
    }

    /// The operation answered.
    func finish(_ result: Result<T?, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    /// The deadline passed or the caller was cancelled: the operation is cancelled, its late result dropped.
    func giveUp(_ result: Result<T?, Error>) {
        guard continuation != nil else { return }
        work?.cancel()
        finish(result)
    }
}
