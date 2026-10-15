//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import CoreData
@testable import OctopusCore

@Suite
struct ModelCoreDataStackMigratorTests {
    /// Content cached by an SDK that ignored the community default avatar has to be fetched again once: the feeds only
    /// download an item whose server date is newer than the stored one, and the server will not move that date again.
    @Test(arguments: [3, 1])
    func upgradingToVersion4MarksEveryCachedContentAsOutdated(from latestVersion: Int) async throws {
        let context = try ModelCoreDataStack(inRam: true).saveContext
        let recent = Date().timeIntervalSince1970

        try await context.performAsync { [context] in
            let post = PostEntity(context: context)
            post.text = "post"
            let contents: [OctoObjectEntity] = [post, CommentEntity(context: context), ReplyEntity(context: context)]
            for (index, entity) in contents.enumerated() {
                entity.uuid = "content-\(index)"
                entity.updateTimestamp = recent
            }
            try context.save()
        }

        let version = await ModelCoreDataStack.Migrator.migrateDb(
            latestVersion: latestVersion, targetVersion: 4, context: context)
        #expect(version == 4)

        let timestamps = try await context.performAsync { [context] in
            try context.fetch(OctoObjectEntity.fetchAllGeneric()).map(\.updateTimestamp)
        }
        #expect(timestamps.count == 3)
        #expect(timestamps.allSatisfy { $0 == Date.distantPast.timeIntervalSince1970 })
    }

    @Test func aDbAlreadyInVersion4IsLeftUntouched() async throws {
        let context = try ModelCoreDataStack(inRam: true).saveContext
        let recent = Date().timeIntervalSince1970

        try await context.performAsync { [context] in
            let post = PostEntity(context: context)
            post.uuid = "post"
            post.text = "post"
            post.updateTimestamp = recent
            try context.save()
        }

        let version = await ModelCoreDataStack.Migrator.migrateDb(latestVersion: 4, targetVersion: 4, context: context)
        #expect(version == 4)

        let timestamps = try await context.performAsync { [context] in
            try context.fetch(OctoObjectEntity.fetchAllGeneric()).map(\.updateTimestamp)
        }
        #expect(timestamps == [recent])
    }
}
