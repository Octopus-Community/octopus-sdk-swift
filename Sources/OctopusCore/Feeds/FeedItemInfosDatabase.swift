//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection

extension Injected {
    static let feedItemInfosDatabase = Injector.InjectedIdentifier<FeedItemInfosDatabase>()
}

class FeedItemInfosDatabase: InjectableObject {
    static let injectedIdentifier = Injected.feedItemInfosDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    /// Deletes every feed item info, of every feed.
    /// - Warning: To be called on the context's queue, from a block that saves afterwards.
    func deleteAllOnQueue() throws {
        try context.fetch(FeedItemInfoEntity.fetchAll()).forEach { context.delete($0) }
    }

    func getAllItemIds() async throws -> [String] {
        return try await context.performAsync { [context] in
            try context.fetch(FeedItemInfoEntity.fetchAll())
                .flatMap {
                    guard let featuredChildId = $0.featuredChildId else {
                        return [$0.itemId]
                    }
                    return [$0.itemId, featuredChildId]

                }
        }
    }

    func feedItemInfos(feedId: String, pageSize: Int, lastPageIdx: Int) async throws -> [FeedItemInfo] {
        return try await context.performAsync { [context] in
            try context.fetch(FeedItemInfoEntity.fetchByFeedAndSorted(
                    feedId: feedId, pageSize: pageSize, lastPageIdx: lastPageIdx))
                .map { FeedItemInfo(from: $0) }
        }
    }

    func deleteAll(feedId: String) async throws {
        try await context.performAsync { [context] in
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = FeedItemInfoEntity.fetchAll(feedId: feedId) as! NSFetchRequest<NSFetchRequestResult>
            deleteRequest.includesPropertyValues = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            try context.execute(batchDeleteRequest)
        }
    }

    /// Deletes the windows (see ``FeedWindowKey``) made by any launch but `launchId`.
    func deleteWindows(exceptOfLaunch launchId: String) async throws {
        try await context.performAsync { [context] in
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = FeedItemInfoEntity.fetchAll()
                as! NSFetchRequest<NSFetchRequestResult>
            let feedIdKey = #keyPath(FeedItemInfoEntity.feedId)
            deleteRequest.predicate = NSPredicate(
                format: "%K CONTAINS %@ AND NOT (%K CONTAINS %@)",
                feedIdKey, FeedWindowKey.marker, feedIdKey, "\(FeedWindowKey.marker)\(launchId).")
            deleteRequest.includesPropertyValues = false
            try context.execute(NSBatchDeleteRequest(fetchRequest: deleteRequest))
        }
    }

    func upsert(feedItemInfos: [FeedItemInfo], feedId: String) async throws {
        try await context.performAsync { [context] in
            // first get the count of the items in the db
            let existingFeedItemInfosCount = try context.count(for: FeedItemInfoEntity.fetchAll(feedId: feedId))

            let existingItemInfos = try context.chunkedFetch(ids: feedItemInfos.map { $0.itemId }) { chunk in
                FeedItemInfoEntity.fetchAll(feedId: feedId, itemIds: chunk)
            }

            // An item already stored keeps its place: a server page may list again an item of the previous one while
            // the feed changes, and moving it to the end would shift the stored items a paging read skips past.
            var nextPosition = existingFeedItemInfosCount
            var upsertedIds = Set<String>()
            for feedItemInfo in feedItemInfos where upsertedIds.insert(feedItemInfo.itemId).inserted {
                let feedItemInfoEntity: FeedItemInfoEntity
                if let existingItemInfo = existingItemInfos.first(where: { $0.itemId == feedItemInfo.itemId }) {
                    feedItemInfoEntity = existingItemInfo
                } else {
                    feedItemInfoEntity = FeedItemInfoEntity(context: context)
                    feedItemInfoEntity.position = nextPosition
                    nextPosition += 1
                }
                feedItemInfoEntity.feedId = feedItemInfo.feedId
                feedItemInfoEntity.itemId = feedItemInfo.itemId
                feedItemInfoEntity.updateTimestamp = feedItemInfo.updateDate.timeIntervalSince1970
                feedItemInfoEntity.featuredChildId = feedItemInfo.featuredChildId
            }

            try context.save()
        }
    }
}
