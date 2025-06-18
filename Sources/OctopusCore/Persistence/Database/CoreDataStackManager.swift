//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os

/// Object that is in charge of loading a core data stack
class CoreDataStackManager: @unchecked Sendable {
    private let persistentContainer: NSPersistentContainer
    lazy var saveContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }()

    // use only one model even in the Unit Tests.
    // cf https://stackoverflow.com/questions/51851485/multiple-nsentitydescriptions-claim-nsmanagedobject-subclass
    nonisolated(unsafe) static var models = [String: NSManagedObjectModel]()

    init(persistentContainerName: String, inRam: Bool = false) throws(CoreDataErrors) {
        persistentContainer = NSPersistentContainer(
            name: persistentContainerName,
            managedObjectModel: try Self.loadModel(name: persistentContainerName)
        )
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

        self.load(inRam: inRam)
    }

    private static func loadModel(name: String) throws(CoreDataErrors) -> NSManagedObjectModel {
        if let model = models[name] {
            return model
        }

        guard let modelURL = Bundle.module.url(forResource: name, withExtension:"momd") else {
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
            persistentContainer.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        persistentContainer.loadPersistentStores { persistentStoreDescription, error in
            if let error {
                if #available(iOS 14, *) {
                    Logger.other.debug("Persistent store couldn't be loaded: \(error) try to reset it at: \(persistentStoreDescription.url?.path ?? "URL not found")")
                }
                do {
                    if let storeUrl = persistentStoreDescription.url,
                       FileManager.default.fileExists(atPath: storeUrl.path) {
                        try FileManager.default.removeItem(at: storeUrl)
                    }
                    try self.reset()
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
            if FileManager.default.fileExists(atPath: storeUrl.path),
               FileManager.default.isDeletableFile(atPath: storeUrl.path) {
                try FileManager.default.removeItem(at: storeUrl)
            }
        }
    }
}
