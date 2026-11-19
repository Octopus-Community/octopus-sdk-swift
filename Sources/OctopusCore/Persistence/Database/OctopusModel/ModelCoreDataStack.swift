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

    lazy var viewContext: NSManagedObjectContext = {
        stackManager.viewContext
    }()

    private static let persistentContainerName = "OctopusModel"
    /// Current version of the database. Used to determine which kind of migration is needed
    /// v3: added desc/ascCommentFeedId to Public/PrivateProfile (String, default "") — a
    /// lightweight, non-resetting migration; the ids populate on the next profile fetch.
    /// v4: added the three optional defaultAvatar* attributes to MinimalProfile, PublicProfile and PrivateProfile. A
    /// lightweight, non-resetting migration; they populate on the next fetch of the profiles. The cached contents are
    /// marked as outdated (see `Migrator.refetchCachedContentForDefaultAvatars`) so that they are fetched again and
    /// fill the default of their author. PrivateProfile also has three defaultAvatarIfPictureRemoved* ones.
    private static let currentVersion: Int = 4

    private let stackManager: CoreDataStackManager

    /// latest version of the database. If it differs from currentVersion, a migration will be done
    private static let latestVersionKey = "OctopusSDK.\(persistentContainerName).Migrator.dbVersion"

    init(forceReset: Bool = false, inRam: Bool = false) throws(CoreDataErrors) {
        stackManager = try CoreDataStackManager(persistentContainerName: Self.persistentContainerName, inRam: inRam) {
            Self.prepareStore(forceReset: forceReset)
        }
    }

    /// Decides from the version the store was left at whether to reset it or migrate it. Called once the store can be
    /// read, the version with it.
    private static func prepareStore(forceReset: Bool) -> CoreDataStackManager.StorePreparation {
        let latestVersion = UserDefaults.standard.integer(forKey: latestVersionKey)
        guard latestVersion != currentVersion else { return .init(eraseExistingContainer: forceReset) }

        guard !forceReset, !Migrator.shouldResetDb(latestVersion: latestVersion, targetVersion: currentVersion) else {
            // Once loaded only: if the load fails, the next try must still see the old version and erase again.
            return .init(eraseExistingContainer: true) { _ in
                UserDefaults.standard.set(currentVersion, forKey: latestVersionKey)
            }
        }
        return .init(eraseExistingContainer: false) { context in
            Task {
                let updatedVersion = await Migrator.migrateDb(
                    latestVersion: latestVersion,
                    targetVersion: currentVersion,
                    context: context)
                UserDefaults.standard.set(updatedVersion, forKey: latestVersionKey)
            }
        }
    }

    func teardown() async throws {
        try await stackManager.teardown()
    }
}
