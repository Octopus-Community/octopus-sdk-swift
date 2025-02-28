//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PostEntity)
class PostEntity: OctoObjectEntity {
    @NSManaged public var headline: String
    @NSManaged public var text: String?
    @NSManaged public var mediasRelationship: NSOrderedSet

    var medias: [MediaEntity] {
        mediasRelationship.array as? [MediaEntity] ?? []
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<PostEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(PostEntity.uuid), id)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchAllByIds(ids: [String]) -> NSFetchRequest<PostEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(PostEntity.uuid), ids)
        return request
    }

    @nonobjc public class func fetchAllExcept(ids: [String]) -> NSFetchRequest<PostEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "NOT (%K IN %@)", #keyPath(PostEntity.uuid), ids)
        return request
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<PostEntity> {
        return NSFetchRequest<PostEntity>(entityName: "Post")
    }
}
