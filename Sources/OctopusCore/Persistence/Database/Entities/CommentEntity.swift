//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(CommentEntity)
class CommentEntity: OctoObjectEntity {
    @NSManaged public var text: String?
    @NSManaged public var mediasRelationship: NSOrderedSet

    var medias: [MediaEntity] {
        mediasRelationship.array as? [MediaEntity] ?? []
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<CommentEntity> {
        return NSFetchRequest<CommentEntity>(entityName: "Comment")
    }

    @nonobjc public class func fetchAllByIds(ids: [String]) -> NSFetchRequest<CommentEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(CommentEntity.uuid), ids)
        return request
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<CommentEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(CommentEntity.uuid), id)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchAllExcept(ids: [String]) -> NSFetchRequest<CommentEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "NOT (%K IN %@)", #keyPath(CommentEntity.uuid), ids)
        return request
    }

    @nonobjc public class func fetchSortedAndByParentId(parentId: String) -> NSFetchRequest<CommentEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(CommentEntity.parentId), parentId)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(CommentEntity.creationTimestamp), ascending: true)]
        return request
    }
}
