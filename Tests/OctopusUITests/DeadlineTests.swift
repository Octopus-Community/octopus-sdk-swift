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
}
