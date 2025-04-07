//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PostEntity)
class PostEntity: OctoObjectEntity {
    @NSManaged public var text: String
    @NSManaged public var mediasRelationship: NSOrderedSet
    @NSManaged public var pollOptionsRelationship: NSOrderedSet?

    var medias: [MediaEntity] {
        mediasRelationship.array as? [MediaEntity] ?? []
    }

    var pollOptions: [PollOptionEntity]? {
        guard let pollOptions = pollOptionsRelationship?.array as? [PollOptionEntity], !pollOptions.isEmpty else {
            return nil
        }
        return pollOptions
    }

    func fill(with post: StorablePost, context: NSManagedObjectContext) {
        super.fill(with: post, context: context)
        text = post.text
        mediasRelationship = NSOrderedSet(array: post.medias.map {
            let mediaEntity = MediaEntity(context: context)
            mediaEntity.url = $0.url
            mediaEntity.type = $0.kind.entity.rawValue
            mediaEntity.width = $0.size.width
            mediaEntity.height = $0.size.height
            return mediaEntity
        })

        if let poll = post.poll {
            pollOptionsRelationship = NSOrderedSet(array: poll.options.map {
                let pollOptionEntity = PollOptionEntity(context: context)
                pollOptionEntity.uuid = $0.id
                pollOptionEntity.text = $0.text
                return pollOptionEntity
            })
        } else {
            pollOptionsRelationship = nil
        }

        if descChildrenFeedId?.nilIfEmpty == nil || post.descCommentFeedId?.nilIfEmpty != nil {
            descChildrenFeedId = post.descCommentFeedId
        }
        if ascChildrenFeedId?.nilIfEmpty == nil || post.ascCommentFeedId?.nilIfEmpty != nil {
            ascChildrenFeedId = post.ascCommentFeedId
        }
    }
}

// Extension that adds all fetch requests needed
extension PostEntity: FetchableContentEntity {
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
