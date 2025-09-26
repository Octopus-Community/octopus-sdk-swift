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

    func upsert(feedItemInfos: [FeedItemInfo], feedId: String) async throws {
        try await context.performAsync { [context] in
            // first get the count of the items in the db
            let existingFeedItemInfosCount = try context.count(for: FeedItemInfoEntity.fetchAll(feedId: feedId))

            let request = FeedItemInfoEntity.fetchAll(feedId: feedId, itemIds: feedItemInfos.map { $0.itemId })
            let existingItemInfos = try context.fetch(request)

            for (index, feedItemInfo) in feedItemInfos.enumerated() {
                let feedItemInfoEntity: FeedItemInfoEntity
                if let existingItemInfo = existingItemInfos.first(where: { $0.itemId == feedItemInfo.itemId }) {
                    feedItemInfoEntity = existingItemInfo
                } else {
                    feedItemInfoEntity = FeedItemInfoEntity(context: context)
                }
                feedItemInfoEntity.feedId = feedItemInfo.feedId
                feedItemInfoEntity.itemId = feedItemInfo.itemId
                feedItemInfoEntity.updateTimestamp = feedItemInfo.updateDate.timeIntervalSince1970
                feedItemInfoEntity.featuredChildId = feedItemInfo.featuredChildId
                feedItemInfoEntity.position = existingFeedItemInfosCount + index
            }

            try context.save()
        }
    }
}
