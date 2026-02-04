//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PostEntity)
class PostEntity: OctoObjectEntity {
    @NSManaged public var text: String
    @NSManaged public var translatedText: String?
    @NSManaged public var originalLanguage: String?
    @NSManaged public var clientObjectId: String?
    @NSManaged public var catchPhrase: String?
    @NSManaged public var translatedCatchPhrase: String?
    @NSManaged public var ctaText: String?
    @NSManaged public var translatedCtaText: String?
    @NSManaged public var customActionText: String?
    @NSManaged public var customActionTranslatedText: String?
    @NSManaged public var customActionTargetLink: String?

    @NSManaged public var mediasRelationship: NSOrderedSet
    @NSManaged public var pollOptionsRelationship: NSOrderedSet?

    var medias: [MediaEntity] {
        mediasRelationship.array as? [MediaEntity] ?? []
    }

    var pollOptions: [PollOptionEntity]? {
        guard let pollOptions = pollOptionsRelationship?.array as? [PollOptionEntity], !pollOptions.isEmpty else {
            return nil
        }
        return pollOptions.removingDuplicates(by: \.uuid)
    }

    func fill(with post: StorablePost, context: NSManagedObjectContext) throws {
        try super.fill(with: post, context: context)
        text = post.text.originalText
        translatedText = post.text.translatedText
        originalLanguage = post.text.originalLanguage
        mediasRelationship = NSOrderedSet(array: post.medias.map {
            let mediaEntity = MediaEntity(context: context)
            mediaEntity.fill(with: $0, context: context)
            return mediaEntity
        })

        if let poll = post.poll {
            pollOptionsRelationship = NSOrderedSet(array: poll.options.map {
                let pollOptionEntity = PollOptionEntity(context: context)
                pollOptionEntity.uuid = $0.id
                pollOptionEntity.text = $0.text.originalText
                pollOptionEntity.translatedText = $0.text.translatedText
                return pollOptionEntity
            })
        } else {
            pollOptionsRelationship = nil
        }

        clientObjectId = post.bridgeClientObjectId
        catchPhrase = post.bridgeCatchPhrase?.originalText
        translatedCatchPhrase = post.bridgeCatchPhrase?.translatedText
        ctaText = post.bridgeCtaText?.originalText
        translatedCtaText = post.bridgeCtaText?.translatedText

        customActionText = post.customActionText?.originalText
        customActionTranslatedText = post.customActionText?.translatedText
        customActionTargetLink = post.customActionTargetLink

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

    @nonobjc public class func fetchByClientObjectId(id: String) -> NSFetchRequest<PostEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(PostEntity.clientObjectId), id)
        return request
    }

    @nonobjc public class func fetchAllExcept(ids: [String]) -> NSFetchRequest<PostEntity> {
        let request = fetchAll()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "NOT (%K IN %@)", #keyPath(PostEntity.uuid), ids),
            // Special case for bridge posts. To avoid deleting them too often, we do not clean them
            NSPredicate(format: "%K = nil", #keyPath(PostEntity.clientObjectId))
        ])
        return request
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<PostEntity> {
        return NSFetchRequest<PostEntity>(entityName: "Post")
    }
}
