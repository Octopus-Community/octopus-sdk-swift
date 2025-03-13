//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import DependencyInjection

extension Injected {
    static let coreDataStack = Injector.InjectedIdentifier<CoreDataStack>()
}

class CoreDataStack: InjectableObject, @unchecked Sendable {

    enum CoreDataErrors: Error, CustomStringConvertible {
        case modelFileNotFound
        case modelFileCorrupted(URL)

        var description: String {
            switch self {
            case .modelFileNotFound:
                return "A model file named \(CoreDataStack.persistentContainerName) cannot be found in the module."
            case let .modelFileCorrupted(url):
                return "The model file located at \(url.relativePath) cannot be used to initialize the " +
                    "NSManagedObjectModel"
            }
        }
    }

    static let injectedIdentifier = Injected.coreDataStack
    private static let persistentContainerName = "OctopusModel"
    // use only one model even in the Unit Tests.
    // cf https://stackoverflow.com/questions/51851485/multiple-nsentitydescriptions-claim-nsmanagedobject-subclass
    nonisolated(unsafe) static let model: NSManagedObjectModel = {
        guard let modelURL = Bundle.module.url(forResource: persistentContainerName, withExtension:"momd") else {
            fatalError("A model file named \(persistentContainerName) cannot be found in the module.")
        }

        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("The model file located at \(modelURL.relativePath) cannot be used to initialize the " +
                       "NSManagedObjectModel")
        }
        return mom
    }()

    let persistentContainer: NSPersistentContainer
    lazy var saveContext: NSManagedObjectContext = {
        persistentContainer.newBackgroundContext()
    }()

    init(inRam: Bool = false) throws(CoreDataErrors) {
        persistentContainer = NSPersistentContainer(name: Self.persistentContainerName, managedObjectModel: Self.model)
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

        self.load(inRam: inRam)
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

    func performInBackground(_ block: @escaping (NSManagedObjectContext) throws -> Void) async rethrows {
        if #available(iOS 15.0, *) {
            try await persistentContainer.performBackgroundTask { context in
                try block(context)
            }
        } else {
            await withCheckedContinuation { continuation in
                persistentContainer.performBackgroundTask { context in
                    try? block(context)
                    continuation.resume()
                }
            }
        }
    }
}
