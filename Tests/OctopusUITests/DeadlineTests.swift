//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@MainActor
struct DeadlineTests {
    private struct Failure: Error {}

    @Test func anOperationThatAnswersInTimeGivesItsValue() async throws {
        let value = try await withDeadline(nanoseconds: 5_000_000_000) { 42 }
        #expect(value == 42)
    }

    @Test func anOperationThatFailsInTimeGivesItsError() async {
        await #expect(throws: Failure.self) {
            _ = try await withDeadline(nanoseconds: 5_000_000_000) { () async throws -> Int in throw Failure() }
        }
    }

    /// The case the deadline exists for: a call stuck on a dead connection, which never notices its cancellation.
    @Test func anOperationThatNeverAnswersGivesUpAtTheDeadline() async throws {
        let value = try await withDeadline(nanoseconds: 50_000_000) { () async throws -> Int in
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
            return 42
        }
        #expect(value == nil)
    }

    /// A member closing the nickname choice while it is sent: the caller does not wait for a call that never answers.
    @Test func cancellingTheCallerThrowsWithoutWaitingForTheOperation() async throws {
        let caller = Task { @MainActor in
            try await withDeadline(nanoseconds: 60_000_000_000) { () async throws -> Int in
                await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
                return 42
            }
        }
        caller.cancel()
        await #expect(throws: CancellationError.self) { _ = try await caller.value }
    }

    @Test func cancellingTheCallerCancelsTheOperation() async throws {
        let operation = OperationRecorder()
        let caller = Task { @MainActor in
            try await withDeadline(nanoseconds: 60_000_000_000) { () async throws -> Int in
                operation.started = true
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    operation.wasCancelled = Task.isCancelled
                    throw error
                }
                return 42
            }
        }
        try await waitUntil { operation.started }
        caller.cancel()
        _ = try? await caller.value
        try await waitUntil { operation.wasCancelled }
    }

    @MainActor
    private final class OperationRecorder {
        var started = false
        var wasCancelled = false
    }
}
