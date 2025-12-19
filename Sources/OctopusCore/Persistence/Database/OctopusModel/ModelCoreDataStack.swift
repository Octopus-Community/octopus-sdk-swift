//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let modelCoreDataStack = Injector.InjectedIdentifier<ModelCoreDataStack>()
}

class ModelCoreDataStack: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.modelCoreDataStack

    lazy var saveContext: NSManagedObjectContext = {
        stackManager.saveContext
    }()

    private static let persistentContainerName = "OctopusModel"
    /// Current version of the database. Used to determine which kind of migration is needed
    private static let currentVersion: Int = 1

    private let stackManager: CoreDataStackManager

    /// latest version of the database. If it differs from currentVersion, a migration will be done
    static private let latestVersionKey = "OctopusSDK.\(persistentContainerName).Migrator.dbVersion"

    init(inRam: Bool = false) throws(CoreDataErrors) {
        let latestVersion = UserDefaults.standard.integer(forKey: Self.latestVersionKey)
        if latestVersion != Self.currentVersion {
            let resetDb = Migrator.shouldResetDb(latestVersion: latestVersion, targetVersion: Self.currentVersion)
            if resetDb {
                UserDefaults.standard.set(latestVersion, forKey: Self.latestVersionKey)
            }
            stackManager = try CoreDataStackManager(
                persistentContainerName: Self.persistentContainerName,
                eraseExistingContainer: resetDb,
                inRam: inRam)

            // no need to do the migration if the db has been reset
            if !resetDb {
                Task {
                    let updatedVersion = await Migrator.migrateDb(
                        latestVersion: latestVersion,
                        targetVersion: Self.currentVersion,
                        context: stackManager.saveContext)
                    UserDefaults.standard.set(updatedVersion, forKey: Self.latestVersionKey)
                }
            }
        } else {
            stackManager = try CoreDataStackManager(
                persistentContainerName: Self.persistentContainerName,
                eraseExistingContainer: false,
                inRam: inRam)
        }
    }
}
