//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

/// Switching community tears the stores of the previous core down while that core is still alive, so a write it
/// already started — a `connectUser` upserting the client user's profile, say — can still be waiting for the save
/// context's queue. Once the store is removed, a `save()` raises an ObjC exception that `try` cannot catch and the app
/// aborts: the write must either land before the teardown or be dropped with an error.
///
/// The save context's queue is held by a gate so that the write and the teardown are queued in a known order. Each
/// of them is started in a task, given `waitForTaskToQueue()` to reach the queue: a task starting later than that
/// would fail the test, never hang it nor abort it.
///
/// The stack can also queue a block of its own: when the database version stored in the test process is an older one
/// (or none), `ModelCoreDataStack.init` starts a migration task. That block is queued before the test's ones, whether
/// ahead of the gate or behind it, and saves while the stores are there, so it does not change their order.
@Suite(.serialized)
struct CoreDataTeardownTests {

    /// The crash: the upsert passed the "stores are loaded" check and waits for the queue when the switch tears the
    /// stores down. It used to `save()` on a coordinator without stores and abort the process.
    @Test func aWriteQueuedBeforeTheTeardownIsSaved() async throws {
        let stack = try ModelCoreDataStack(inRam: true)
        let database = makeClientUserProfileDatabase(stack: stack)
        let gate = QueueGate(holding: stack.saveContext)
        // Opened on every path, so that a test failing early does not leave the queue's thread parked.
        defer { gate.open() }

        let write = Task { try await database.upsert(profile: profile, clientUserId: "clientUserId") }
        try await waitForTaskToQueue()
        let teardown = Task { try await stack.teardown() }
        try await waitForTaskToQueue()
        gate.open()

        try await write.value
        try await teardown.value
        #expect(stack.saveContext.persistentStoreCoordinator?.persistentStores.isEmpty == true)
    }

    /// The stores are still there when the upsert checks them, but the teardown runs first on the queue.
    @Test func aWriteQueuedAfterTheTeardownIsDropped() async throws {
        let stack = try ModelCoreDataStack(inRam: true)
        let database = makeClientUserProfileDatabase(stack: stack)
        let gate = QueueGate(holding: stack.saveContext)
        // Opened on every path, so that a test failing early does not leave the queue's thread parked.
        defer { gate.open() }

        let teardown = Task { try await stack.teardown() }
        try await waitForTaskToQueue()
        let write = Task { try await database.upsert(profile: profile, clientUserId: "clientUserId") }
        try await waitForTaskToQueue()
        gate.open()

        let error = await #expect(throws: CoreDataErrors.self) { try await write.value }
        guard case .storesTornDown = error else {
            Issue.record("Expected storesTornDown, got \(String(describing: error))")
            return
        }
        try await teardown.value
        #expect(stack.saveContext.persistentStoreCoordinator?.persistentStores.isEmpty == true)
    }

    /// Leaves a task just started the time to queue its block behind the gate: it has no suspension point before that.
    private func waitForTaskToQueue() async throws {
        try await Task.sleep(nanoseconds: .secondsToNano(0.5))
    }

    private let profile = ClientUserProfile(nickname: "Nickname", bio: nil, picture: nil)

    private func makeClientUserProfileDatabase(stack: ModelCoreDataStack) -> ClientUserProfileDatabase {
        let injector = Injector()
        injector.register { _ in stack }
        injector.register { ClientUserProfileDatabase(injector: $0) }
        return injector.getInjected(identifiedBy: Injected.clientUserProfileDatabase)
    }
}

/// Keeps a context's queue busy until `open()` is called, as the launch's other writes can in an app.
private final class QueueGate: Sendable {
    private let semaphore = DispatchSemaphore(value: 0)

    init(holding context: NSManagedObjectContext) {
        context.perform { [semaphore] in semaphore.wait() }
    }

    /// Can be called again: the queue is only held once.
    func open() {
        semaphore.signal()
    }
}
