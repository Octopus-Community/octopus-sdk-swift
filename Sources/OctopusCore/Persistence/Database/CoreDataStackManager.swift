//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os

extension Notification.Name {
    /// Posted by a `CoreDataStackManager` once its stores are loaded, with their coordinator as object.
    static let persistentStoresDidLoad = Notification.Name("OctopusSDK.persistentStoresDidLoad")
}

/// Object that is in charge of loading a core data stack
///
/// The store is only loaded once its files can be read. A host app can create the SDK during a launch in the background
/// before the device's first unlock after a reboot, when iOS refuses to open them: the stack then waits for the device
/// to be unlocked, without stores: the reads find nothing and the writes fail meanwhile. Taking that for a broken store
/// would delete the files, and the tracking events not sent yet with them.
class CoreDataStackManager: @unchecked Sendable {
    /// What to do with a store before and after loading it, decided once its files can be read.
    struct StorePreparation {
        /// Whether to delete the existing store and start from an empty one.
        let eraseExistingContainer: Bool
        /// Run once the store is loaded, with the save context.
        let afterLoad: ((NSManagedObjectContext) -> Void)?

        init(eraseExistingContainer: Bool, afterLoad: ((NSManagedObjectContext) -> Void)? = nil) {
            self.eraseExistingContainer = eraseExistingContainer
            self.afterLoad = afterLoad
        }
    }

    private enum LoadState {
        /// The store's files cannot be read yet.
        case waitingForUnlock
        case loaded
        /// Torn down while waiting or once loaded: never loaded again.
        case tornDown
    }

    /// The URL of an in-RAM store: SQLite keeps it in memory, there is no file to delete.
    private static let inRamStoreURL = URL(fileURLWithPath: "/dev/null")

    private let persistentContainer: NSPersistentContainer
    private let inRam: Bool
    private let storeIsLocked: (URL) -> Bool
    private let prepare: () -> StorePreparation
    /// Guards `loadState` and `loadSubscription`: the store can be loaded on the thread of a trigger while the stack is
    /// torn down from another one.
    private let loadLock = NSLock()
    private var loadState = LoadState.waitingForUnlock
    /// Watches the moments to load a store that could not be read yet; dropped once it is loaded or torn down.
    private var loadSubscription: AnyCancellable?

    lazy var saveContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }()

    lazy var viewContext: NSManagedObjectContext = {
        persistentContainer.viewContext
    }()

    // use only one model even in the Unit Tests.
    // cf https://stackoverflow.com/questions/51851485/multiple-nsentitydescriptions-claim-nsmanagedobject-subclass
    // Guarded by `modelsLock`: stacks can be created concurrently (e.g. parallel test suites).
    private static let modelsLock = NSLock()
    nonisolated(unsafe) private static var models = [String: NSManagedObjectModel]()

    /// - Parameters:
    ///   - storeDirectory: where to keep the store's files; the container's default directory if `nil`.
    ///   - storeIsLocked: whether the store's file cannot be opened yet. Replaced by the tests, since a simulator
    ///     never refuses to open a file.
    ///   - loadTriggers: when to try again to load a store that could not be read. Replaced by the tests, which must
    ///     not post system notifications to every stack alive in the process.
    ///   - prepare: what to do with the store, only called once its files can be read: before the first unlock,
    ///     `UserDefaults`, where the stacks keep the version of their store, answers as if nothing were stored.
    init(persistentContainerName: String, inRam: Bool = false, storeDirectory: URL? = nil,
         storeIsLocked: @escaping (URL) -> Bool = CoreDataStackManager.fileIsProtected(at:),
         loadTriggers: AnyPublisher<Void, Never> = ProtectedDataTriggers.default,
         prepare: @escaping () -> StorePreparation) throws(CoreDataErrors) {
        persistentContainer = NSPersistentContainer(
            name: persistentContainerName,
            managedObjectModel: try Self.loadModel(name: persistentContainerName)
        )
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        if inRam {
            persistentContainer.persistentStoreDescriptions.first!.url = Self.inRamStoreURL
        } else if let storeDirectory {
            persistentContainer.persistentStoreDescriptions.first!.url =
                storeDirectory.appendingPathComponent("\(persistentContainerName).sqlite")
        }
        self.inRam = inRam
        self.storeIsLocked = storeIsLocked
        self.prepare = prepare

        let isLoaded = loadStoreIfReadable()
        // Created in init at the latest, before the stack is shared, rather than on first use: every write and the
        // teardown must go through this one context, and a lazy var created from two threads at once (a trigger and
        // a write, say) can make two. A first load that resets or migrates the store already created it, for its
        // `afterLoad`. After the first load anyway, as CoreData warns about a context created before the stores
        // are: it rightly does for a store waiting for the device to be unlocked only.
        _ = saveContext

        // Only needed until the store is loaded: `loadStoreIfReadable` drops this subscription once it is.
        guard !isLoaded else { return }
        // Subscribed outside the lock, since a trigger may fire right away and take it, then kept only if the store is
        // still waiting by then.
        let subscription = loadTriggers.sink { [weak self] in self?.loadStoreIfReadable() }
        loadLock.lock()
        let isWaiting = loadState == .waitingForUnlock
        if isWaiting { loadSubscription = subscription }
        loadLock.unlock()
        // The device may have been unlocked between the first try and the subscription, with no trigger left to tell.
        if isWaiting { loadStoreIfReadable() }
    }

    /// Whether the file exists but cannot be opened: iOS refuses to open a file protected until the first unlock, the
    /// default protection of an app's files, before the device is unlocked once after a reboot. A missing file or a
    /// corrupted one is not protected; a missing one that cannot be created yet makes the load fail, which is tried
    /// again later (`loadStoreIfReadable`).
    static func fileIsProtected(at url: URL) -> Bool {
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor < 0 else {
            close(descriptor)
            return false
        }
        return errno == EPERM
    }

    /// Loads the store, unless its files cannot be read yet or the stack has been torn down.
    /// - Returns: whether the stack is done waiting: its store is loaded, or will never be.
    @discardableResult
    private func loadStoreIfReadable() -> Bool {
        loadLock.lock()
        guard loadState == .waitingForUnlock else {
            loadLock.unlock()
            return true
        }
        if !inRam, let storeURL = persistentContainer.persistentStoreDescriptions.first?.url, storeIsLocked(storeURL) {
            loadLock.unlock()
            if #available(iOS 14, *) {
                Logger.other.debug("The \(self.persistentContainer.name) db cannot be read until the device is unlocked")
            }
            return false
        }

        let preparation = prepare()
        if preparation.eraseExistingContainer {
            if #available(iOS 14, *) { Logger.other.trace("Reset of the \(self.persistentContainer.name) db needed") }
            do {
                try deleteSQLiteStoreFiles(for: persistentContainer)
            } catch {
                if #available(iOS 14, *) { Logger.other.debug("Failed to delete persistent store: \(error)") }
            }
        }
        // The stores are loaded once this returns, since they are added synchronously (`shouldAddStoreAsynchronously`
        // is left to false).
        load()
        // Even its reset can fail: before the first unlock, a store that has no file yet (one an SDK update adds, or
        // one torn down while waiting) cannot be created either. Tried again on the next trigger.
        guard !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty else {
            loadLock.unlock()
            if #available(iOS 14, *) {
                Logger.other.debug("The \(self.persistentContainer.name) db could not be loaded, trying again later")
            }
            return false
        }
        loadState = .loaded
        loadSubscription = nil
        loadLock.unlock()

        preparation.afterLoad?(saveContext)
        // Outside the lock, as the migration above: the subscribers fetch on the contexts' queues.
        NotificationCenter.default.post(name: .persistentStoresDidLoad,
                                        object: persistentContainer.persistentStoreCoordinator)
        return true
    }

    private static func loadModel(name: String) throws(CoreDataErrors) -> NSManagedObjectModel {
        modelsLock.lock()
        defer { modelsLock.unlock() }

        if let model = models[name] {
            return model
        }

        guard let modelURL = Bundle.module.url(forResource: name, withExtension: "momd") else {
            throw .modelFileNotFound(name)
        }

        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            throw .modelFileCorrupted(modelURL)
        }
        models[name] = mom
        return mom
    }

    /// Load persistent stores. In case of error, delete the existing persistent stores and create/load it again.
    ///
    /// Only called once the store's file can be opened, or does not exist (`loadStoreIfReadable`): an error is then
    /// about the store itself, or about a missing file that cannot be created before the first unlock, which deleting
    /// does not change.
    ///
    /// - Note: Add a persistent store with specific type to persistent container if needed
    ///
    /// - Parameters:
    ///     - retry: Whether the app should retry loading persistent stores in case of error
    private func load(retry: Bool = true) {
        persistentContainer.loadPersistentStores { [weak self] persistentStoreDescription, error in
            guard let self else { return }
            if let error {
                if #available(iOS 14, *) {
                    Logger.other.debug("Persistent store couldn't be loaded: \(error) try to reset it at: \(persistentStoreDescription.url?.path ?? "URL not found")")
                }
                do {
                    if let storeUrl = persistentStoreDescription.url {
                        try deleteSQLiteFiles(at: storeUrl)
                    }
                    try reset()
                } catch {
                    if #available(iOS 14, *) { Logger.other.debug("failed to delete Persistent store: \(error)") }
                }

                if retry {
                    self.load(retry: false)
                } else {
                    if #available(iOS 14, *) { Logger.other.debug("failed to delete Persistent store: \(error)") }
                }
            }
        }
    }

    /// Removes the persistent stores of a stack that is not used anymore, as when switching community.
    ///
    /// The stack's owner can still be alive, and so can a write it started: the stores are removed on the queue of
    /// `saveContext`, the context every write goes through, so a write queued before the teardown is saved first
    /// and one queued after it finds no store and is dropped by `performAsync(_:)`, instead of a `save()` reaching
    /// a coordinator whose store is gone.
    ///
    /// A store still waiting for the device to be unlocked is never loaded afterwards, and its files are deleted.
    func teardown() async throws {
        stopLoading()
        try await saveContext.performOnQueue { [self] in try reset() }
    }

    private func stopLoading() {
        loadLock.lock()
        defer { loadLock.unlock() }
        let wasWaiting = loadState == .waitingForUnlock
        loadState = .tornDown
        loadSubscription = nil
        // `reset()` only deletes the files of the loaded stores. Left on disk, the files of a store that was waiting
        // would be loaded by the next launch, which knows nothing of the switch, with the previous community's data.
        guard wasWaiting else { return }
        do {
            try deleteSQLiteStoreFiles(for: persistentContainer)
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Failed to delete persistent store: \(error)") }
        }
    }

    /// Remove all existing persistent stores associated to the persistent container
    ///
    /// - Note: Call this method to completely wipe all stored datas. `load()`
    ///     must be called to recreate a brand new file.
    private func reset() throws {
        for persistentStore in persistentContainer.persistentStoreCoordinator.persistentStores {
            try persistentContainer.persistentStoreCoordinator.remove(persistentStore)

            guard let storeUrl = persistentStore.url else {
                return
            }
            try deleteSQLiteFiles(at: storeUrl)
        }
    }

    // MARK: - File Deletion Utilities

    /// Deletes all SQLite-related files BEFORE the stores are loaded.
    private func deleteSQLiteStoreFiles(for container: NSPersistentContainer) throws {
        for desc in container.persistentStoreDescriptions {
            if let url = desc.url {
                try deleteSQLiteFiles(at: url)
            }
        }
    }

    /// Delete .sqlite, .sqlite-wal, .sqlite-shm files
    private func deleteSQLiteFiles(at storeURL: URL) throws {
        guard storeURL.path != Self.inRamStoreURL.path else { return }
        let urls = [
            storeURL,
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
            storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        ]

        for url in urls {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
