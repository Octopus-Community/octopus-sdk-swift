//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os

/// Extension of TrackingCoreDataStack that adds the migration logic
extension TrackingCoreDataStack {
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

            guard latestVersion > 0 else {
                // db version of 0 means fresh install (except if coming from a version that had no db version)
                return false
            }

            // uncomment if version X needs a full deletion of the db file
            // if latestVersion < X {
            //     return true
            // }
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

            guard latestVersion > 0 else {
                // db version of 0 means fresh install (except if coming from a version that had no db version)
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
    }
}
