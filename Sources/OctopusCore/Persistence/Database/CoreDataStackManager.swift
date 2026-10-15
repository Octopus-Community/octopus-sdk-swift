//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os

/// Object that is in charge of loading a core data stack
class CoreDataStackManager: @unchecked Sendable {
    /// The URL of an in-RAM store: SQLite keeps it in memory, there is no file to delete.
    private static let inRamStoreURL = URL(fileURLWithPath: "/dev/null")

    private let persistentContainer: NSPersistentContainer
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

    init(persistentContainerName: String, eraseExistingContainer: Bool = false, inRam: Bool = false) throws(CoreDataErrors) {
        persistentContainer = NSPersistentContainer(
            name: persistentContainerName,
            managedObjectModel: try Self.loadModel(name: persistentContainerName)
        )
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

        if eraseExistingContainer {
            if #available(iOS 14, *) { Logger.other.trace("Reset of the \(persistentContainerName) db needed") }
            do {
                try deleteSQLiteStoreFiles(for: persistentContainer)
            } catch {
                if #available(iOS 14, *) { Logger.other.debug("Failed to delete persistent store: \(error)") }
            }
        }

        self.load(inRam: inRam)
        // Created here, before the stack is shared, rather than on first use: every write and the teardown must
        // go through this one context, and a lazy var created from two threads at once (a migration task and the
        // databases' init) can make two. The stores are loaded by now, since they are added synchronously
        // (`shouldAddStoreAsynchronously` is left to false).
        _ = saveContext
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
    /// - Note: Add a persistent store with specific type to persistent container if needed
    ///
    /// - Parameters:
    ///     - inRam: Whether to host the db in ram or in a persistent file
    ///     - retry: Whether the app should retry loading persistent stores in case of error
    private func load(inRam: Bool, retry: Bool = true) {
        if inRam {
            persistentContainer.persistentStoreDescriptions.first!.url = Self.inRamStoreURL
        }

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
                    self.load(inRam: inRam, retry: false)
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
    func teardown() async throws {
        try await saveContext.performOnQueue { [self] in try reset() }
    }

    /// Remove all existing persistent stores associated to the persistent container
    ///
    /// - Note: Call this method to completely wipe all stored datas. `load(inRam:)`
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
