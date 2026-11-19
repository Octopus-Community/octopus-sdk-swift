//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
@preconcurrency import CoreData
import Combine
import Testing
@testable import OctopusCore

/// A host app can create the SDK during a launch in the background before the device's first unlock after a reboot.
/// The databases' files cannot be opened then, and the stack used to take that for a broken store: it deleted the
/// files, losing among them the tracking events not sent yet. A store that cannot be read yet must be left as it is,
/// and loaded once it can.
///
/// The stores are real files, in a directory of their own, so that what is kept on disk can be checked. Whether a file
/// can be read is decided by the test, since a simulator never refuses to open a file.
@Suite(.serialized)
final class CoreDataStackLoadingTests {
    private let directory: URL
    /// Stands for the device being unlocked or the app coming back.
    private let loadTrigger = PassthroughSubject<Void, Never>()
    /// Whether the store's files cannot be opened, as before the device's first unlock.
    private var isLocked = false
    private var prepareCount = 0
    private var afterLoadCount = 0
    private var eraseOnPrepare = false
    private var storage = [AnyCancellable]()

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreDataStackLoadingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func aReadableStoreIsLoadedRightAway() async throws {
        try await storeConfig()

        let stackManager = try makeStackManager()

        #expect(hasStores(stackManager))
        #expect(prepareCount == 1)
        #expect(afterLoadCount == 1)
        #expect(try await configCount(in: stackManager) == 1)
    }

    /// Before the first unlock, nothing about the store can be decided: the version it was left at is in
    /// `UserDefaults`, which answers as if nothing were stored. It is neither prepared, erased nor loaded.
    @Test func aStoreThatCannotBeReadYetIsKept() async throws {
        try await storeConfig()
        isLocked = true
        eraseOnPrepare = true

        let stackManager = try makeStackManager()

        #expect(!hasStores(stackManager))
        #expect(prepareCount == 0)
        #expect(afterLoadCount == 0)
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
    }

    @Test func theStoreIsLoadedOnceItCanBeRead() async throws {
        try await storeConfig()
        isLocked = true
        let stackManager = try makeStackManager()

        loadTrigger.send()
        #expect(!hasStores(stackManager), "still locked: the store cannot be loaded yet")

        isLocked = false
        loadTrigger.send()

        #expect(hasStores(stackManager))
        #expect(prepareCount == 1)
        #expect(afterLoadCount == 1)
        #expect(try await configCount(in: stackManager) == 1)

        loadTrigger.send()
        #expect(prepareCount == 1, "the store is only loaded once")
    }

    /// Reading a store that is not loaded finds nothing: the subscribers have to read it again once it is loaded,
    /// since no save will tell them to.
    @Test func aPublisherSubscribedBeforeTheLoadPublishesTheStoredData() async throws {
        try await storeConfig()
        isLocked = true
        let stackManager = try makeStackManager()
        let deliveries = Deliveries()
        stackManager.saveContext
            .publisher(request: CommunityConfigEntity.fetch()) { $0 }
            .sink { deliveries.append(count: $0.count, onMainThread: Thread.isMainThread) }
            .store(in: &storage)

        isLocked = false
        // From the main thread, as the system notifications that trigger the load in the app.
        let loadTrigger = UncheckedSendableBox(value: loadTrigger)
        await MainActor.run { loadTrigger.value.send() }

        try await expectWithTimeout(deliveries.last?.count == 1)
        // Not on the thread of the load, which would wait for the context's queue once per publisher. The main thread
        // never runs the blocks of a private queue context.
        #expect(deliveries.last?.onMainThread == false)
    }

    /// A community switch can tear the stack down before the device is unlocked: its store must not be loaded after.
    @Test func aStackTornDownBeforeTheLoadIsNeverLoaded() async throws {
        try await storeConfig()
        isLocked = true
        let stackManager = try makeStackManager()

        try await stackManager.teardown()
        isLocked = false
        loadTrigger.send()

        #expect(!hasStores(stackManager))
        #expect(prepareCount == 0)
        // Left on disk, its files would be loaded by the next launch, which knows nothing of the switch.
        #expect(!FileManager.default.fileExists(atPath: storeURL.path))
    }

    /// The device can be unlocked between the first try and the subscription to the triggers, with none left to fire.
    @Test func anUnlockBeforeTheSubscriptionIsNotMissed() throws {
        isLocked = true
        let triggers = loadTrigger
            .handleEvents(receiveSubscription: { [unowned self] _ in isLocked = false })
            .eraseToAnyPublisher()

        let stackManager = try makeStackManager(loadTriggers: triggers)

        #expect(hasStores(stackManager))
    }

    /// Before the first unlock, a store that has no file yet cannot be created either: the stack must not settle for
    /// having no store.
    @Test func aStoreThatCannotBeLoadedIsTriedAgain() throws {
        // A file where the store's directory should be: the store can neither be opened nor created.
        let storeDirectory = directory.appendingPathComponent("blocked")
        try Data().write(to: storeDirectory)
        let stackManager = try makeStackManager(storeDirectory: storeDirectory)
        #expect(!hasStores(stackManager))
        #expect(afterLoadCount == 0)

        try FileManager.default.removeItem(at: storeDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        loadTrigger.send()

        #expect(hasStores(stackManager))
        #expect(afterLoadCount == 1)
    }

    @Test func aReadableStoreIsErasedWhenItsVersionAsksForIt() async throws {
        try await storeConfig()
        eraseOnPrepare = true

        let stackManager = try makeStackManager()

        #expect(try await configCount(in: stackManager) == 0)
    }

    /// An in-RAM store has no file to wait for.
    @Test func anInRamStoreIsLoadedRightAway() throws {
        isLocked = true

        let stackManager = try makeStackManager(inRam: true)

        #expect(hasStores(stackManager))
        #expect(prepareCount == 1)
    }

    @Test func noTriggerIsWatchedWhenTheStoreIsReadable() throws {
        var subscribed = false
        let triggers = loadTrigger
            .handleEvents(receiveSubscription: { _ in subscribed = true })
            .eraseToAnyPublisher()

        let stackManager = try makeStackManager(loadTriggers: triggers)

        #expect(hasStores(stackManager))
        #expect(!subscribed)
    }

    @Test func theTriggersAreDroppedOnceTheStoreIsLoaded() throws {
        isLocked = true
        var cancelled = false
        let triggers = loadTrigger
            .handleEvents(receiveCancel: { cancelled = true })
            .eraseToAnyPublisher()
        let stackManager = try makeStackManager(loadTriggers: triggers)

        loadTrigger.send()
        #expect(!cancelled, "still locked: the triggers are still needed")

        isLocked = false
        loadTrigger.send()

        #expect(hasStores(stackManager))
        #expect(cancelled)
    }

    /// Only a file iOS refuses to open is protected: a fresh install has no file, and a corrupted store can be opened.
    @Test func aMissingOrReadableFileIsNotProtected() throws {
        let file = directory.appendingPathComponent("file")
        #expect(!CoreDataStackManager.fileIsProtected(at: file))

        try Data("not a database".utf8).write(to: file)
        #expect(!CoreDataStackManager.fileIsProtected(at: file))
    }

    // MARK: - Helpers

    private var storeURL: URL { directory.appendingPathComponent("OctopusConfig.sqlite") }

    private func hasStores(_ stackManager: CoreDataStackManager) -> Bool {
        stackManager.saveContext.persistentStoreCoordinator?.persistentStores.isEmpty == false
    }

    private func makeStackManager(inRam: Bool = false, storeDirectory: URL? = nil,
                                  loadTriggers: AnyPublisher<Void, Never>? = nil) throws -> CoreDataStackManager {
        try CoreDataStackManager(
            persistentContainerName: "OctopusConfig",
            inRam: inRam,
            storeDirectory: storeDirectory ?? directory,
            storeIsLocked: { [unowned self] _ in isLocked },
            loadTriggers: loadTriggers ?? loadTrigger.eraseToAnyPublisher(),
            prepare: { [unowned self] in
                prepareCount += 1
                return .init(eraseExistingContainer: eraseOnPrepare) { [unowned self] _ in afterLoadCount += 1 }
            })
    }

    /// Leaves a store holding one community config in the directory, as a previous launch would.
    private func storeConfig() async throws {
        let stackManager = try CoreDataStackManager(
            persistentContainerName: "OctopusConfig",
            storeDirectory: directory,
            storeIsLocked: { _ in false },
            loadTriggers: Empty().eraseToAnyPublisher(),
            prepare: { .init(eraseExistingContainer: false) })
        let context = stackManager.saveContext
        try await context.performAsync {
            _ = CommunityConfigEntity(context: context)
            try context.save()
        }
    }

    private func configCount(in stackManager: CoreDataStackManager) async throws -> Int {
        let context = stackManager.saveContext
        return try await context.performAsync { try context.count(for: CommunityConfigEntity.fetch()) }
    }
}

/// What a publisher delivered, from whichever thread it delivered it.
private final class Deliveries: @unchecked Sendable {
    struct Delivery {
        let count: Int
        let onMainThread: Bool
    }

    private let lock = NSLock()
    private var deliveries = [Delivery]()

    var last: Delivery? {
        lock.lock()
        defer { lock.unlock() }
        return deliveries.last
    }

    func append(count: Int, onMainThread: Bool) {
        lock.lock()
        defer { lock.unlock() }
        deliveries.append(Delivery(count: count, onMainThread: onMainThread))
    }
}

/// Hands a value Swift cannot prove `Sendable` to the main actor, while the test waits for it.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}
