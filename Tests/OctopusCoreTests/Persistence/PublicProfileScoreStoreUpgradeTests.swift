//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
import CoreData
@testable import OctopusCore

/// A store written by an SDK whose model had no public score, opened by this one: adding an optional attribute is a
/// lightweight migration Core Data does on its own, so the cached public profiles survive, with no score until their
/// next fetch. The model version (`ModelCoreDataStack.currentVersion`) is left as is.
@Suite(.serialized)
struct PublicProfileScoreStoreUpgradeTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PublicProfileScoreStoreUpgradeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test func aStoreWrittenWithoutTheScoreKeepsItsPublicProfiles() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let currentModel = try ModelCoreDataStack(inRam: true).saveContext.persistentStoreCoordinator!.managedObjectModel
        try writeStoreWithoutTheScore(from: currentModel)

        let stack = try CoreDataStackManager(
            persistentContainerName: "OctopusModel",
            storeDirectory: directory,
            storeIsLocked: { _ in false },
            loadTriggers: Empty().eraseToAnyPublisher(),
            prepare: { .init(eraseExistingContainer: false) })

        let profile = try await stack.saveContext.performAsync { [context = stack.saveContext] in
            try context.fetch(PublicProfileEntity.fetchById(id: "member")).first.map(StorableProfile.init(from:))
        }
        #expect(profile?.nickname == "Member")
        #expect(profile?.gamificationLevel == 2)
        #expect(profile?.gamificationScore == nil)

        try await stack.teardown()
    }

    /// Writes, with the model as it was before the public score (the current one without that attribute), a store
    /// holding one public profile, then closes it.
    private func writeStoreWithoutTheScore(from currentModel: NSManagedObjectModel) throws {
        let previousModel = try #require(currentModel.copy() as? NSManagedObjectModel)
        for entity in previousModel.entities {
            // Plain managed objects: the SDK's classes are already claimed by the current model.
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        let publicProfile = try #require(previousModel.entitiesByName["PublicProfile"])
        publicProfile.properties = publicProfile.properties.filter { $0.name != "gamificationScoreOptional" }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: previousModel)
        // The APIs of iOS 13: the test targets are built for it too.
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil,
            at: directory.appendingPathComponent("OctopusModel.sqlite"), options: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var saveError: Error?
        context.performAndWait {
            let profile = NSManagedObject(entity: publicProfile, insertInto: context)
            profile.setValue("member", forKey: "profileId")
            profile.setValue("Member", forKey: "nickname")
            profile.setValue("desc", forKey: "descPostFeedId")
            profile.setValue("asc", forKey: "ascPostFeedId")
            profile.setValue(NSNumber(value: 2), forKey: "gamificationLevelOptional")
            do {
                try context.save()
            } catch {
                saveError = error
            }
        }
        if let saveError { throw saveError }
        try coordinator.remove(store)
    }
}
