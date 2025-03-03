//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(FeedItemInfoEntity)
class FeedItemInfoEntity: NSManagedObject, Identifiable {

    @NSManaged public var feedId: String
    @NSManaged public var itemId: String
    @NSManaged public var updateTimestamp: Double
    @NSManaged public var position: Int

    @nonobjc public class func fetchByFeedAndSorted(
        feedId: String, pageSize: Int, lastPageIdx: Int)
    -> NSFetchRequest<FeedItemInfoEntity> {
        let request = fetchAll(feedId: feedId)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedItemInfoEntity.position), ascending: true)]
        request.fetchOffset = lastPageIdx
        request.fetchLimit = pageSize
        return request
    }

    @nonobjc public class func fetchAll(feedId: String) -> NSFetchRequest<FeedItemInfoEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(FeedItemInfoEntity.feedId), feedId)
        return request
    }

    @nonobjc public class func fetchAll(feedId: String, itemIds: [String]) -> NSFetchRequest<FeedItemInfoEntity> {
        let request = fetchAll()
        let feedIdPredicate = NSPredicate(format: "%K LIKE %@", #keyPath(FeedItemInfoEntity.feedId), feedId)
        let itemIdPredicate = NSPredicate(format: "%K IN %@", #keyPath(FeedItemInfoEntity.itemId), itemIds)
        let andPredicate = NSCompoundPredicate(type: .and, subpredicates: [feedIdPredicate, itemIdPredicate])
        request.predicate = andPredicate
        return request
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<FeedItemInfoEntity> {
        return NSFetchRequest<FeedItemInfoEntity>(entityName: "FeedItemInfo")
    }
}
