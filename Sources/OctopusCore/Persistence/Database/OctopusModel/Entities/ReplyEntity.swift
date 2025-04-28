//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(ReplyEntity)
class ReplyEntity: ResponseEntity {

}

// Extension that adds all fetch requests needed
extension ReplyEntity: FetchableContentEntity {
    @nonobjc public class func fetchAll() -> NSFetchRequest<ReplyEntity> {
        return NSFetchRequest<ReplyEntity>(entityName: "Reply")
    }

    @nonobjc public class func fetchAllByIds(ids: [String]) -> NSFetchRequest<ReplyEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(ReplyEntity.uuid), ids)
        return request
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<ReplyEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(ReplyEntity.uuid), id)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchAllExcept(ids: [String]) -> NSFetchRequest<ReplyEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "NOT (%K IN %@)", #keyPath(ReplyEntity.uuid), ids)
        return request
    }
}
