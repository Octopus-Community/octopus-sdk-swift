//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(CommentEntity)
class CommentEntity: ResponseEntity {
    func fill(with comment: StorableComment, context: NSManagedObjectContext) {
        super.fill(with: comment, context: context)
        if descChildrenFeedId?.nilIfEmpty == nil || comment.descReplyFeedId?.nilIfEmpty != nil {
            descChildrenFeedId = comment.descReplyFeedId
        }
        if ascChildrenFeedId?.nilIfEmpty == nil || comment.ascReplyFeedId?.nilIfEmpty != nil {
            ascChildrenFeedId = comment.ascReplyFeedId
        }
    }
}

// Extension that adds all fetch requests needed
extension CommentEntity: FetchableContentEntity {
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
}
