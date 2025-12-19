//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os

/// Extension of ModelCoreDataStack that adds the migration logic
extension ModelCoreDataStack {
    enum Migrator {
        /// Whether moving from latestVersion to targetVersion needs a hard db migration i.e. deleting the db file to
        /// start with a new, clean, one.
        /// - Parameters:
        ///   - latestVersion: the version of the db file
        ///   - targetVersion: the version to move to
        /// - Returns: true if the db file should be deleted
        static func shouldResetDb(latestVersion: Int, targetVersion: Int) -> Bool {
            guard latestVersion != targetVersion else {
                // no migration to do
                return false
            }

            guard latestVersion < targetVersion else {
                // if the target version is less than the current version, it means that the client did a rollback to a
                // previous sdk version
                // For security, fully reset the db
                return true
            }

            if latestVersion < 1 {
                return false
            }
            return false
        }

        /// Do a soft custom migration if needed
        /// - Parameters:
        ///   - latestVersion: the version of the db file
        ///   - targetVersion: the version to move to
        ///   - context: the db save context
        /// - Returns: the version it was able to update to
        static func migrateDb(latestVersion: Int, targetVersion: Int, context: NSManagedObjectContext) async -> Int {
            guard latestVersion != targetVersion, latestVersion < targetVersion else {
                // no migration to do
                return targetVersion
            }

            // this is needed because the db version has been put in place after the first public sdk version,
            // so there might be people that have a latestVersion = 0 not because it is a fresh install, but because
            // they are coming from an sdk version that had no db version
            guard latestVersion > 0 else {
                do {
                    try await moveOctoObjectAuthorToMinimalProfileRelationship(context: context)
                } catch {
                    if #available(iOS 14, *) { Logger.other.debug("Error during migration from version 0 to \(targetVersion): \(error)") }
                }
                return targetVersion
            }

            var updatedToVersion = latestVersion
            // uncomment if the version X needs a custom migration
            // do {
            //     if latestVersion < X {
            //         try await migrateToVersionX() (see in ModelCoreDataStack.Migrator for an example)
            //         updatedToVersion = 1
            //     }
                updatedToVersion = targetVersion
            // } catch {
            //     if #available(iOS 14, *) { Logger.other.debug("Error during migration from version \(updatedToVersion) to \(targetVersion): \(error)") }
            // }

            return updatedToVersion
        }

        /// This migration was introduced in the 1.8.0.
        /// It deprecated the old way to handle the author of a content: it was fields on each OctoObject.
        /// The new way is to have a relationship that points to a MinimalProfile. This way, the minimal profile is
        /// shared among all octoobjects. If a update comes on one MinimalProfile, it will be propagated to all
        /// contents it has authored.
        static func moveOctoObjectAuthorToMinimalProfileRelationship(context: NSManagedObjectContext) async throws {
            if #available(iOS 14, *) { Logger.other.trace("Migrating Model db: moving author to minimal profile") }
            try await context.performAsync { [context] in
                let request = OctoObjectEntity.fetchAllGeneric()
                let existingContents = try context.fetch(request)

                for existingContent in existingContents {
                    existingContent.updateTimestamp = Date.distantPast.timeIntervalSince1970
                }
                try context.save()
            }
        }
    }
}
