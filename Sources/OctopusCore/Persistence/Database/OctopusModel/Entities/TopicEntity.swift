//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(TopicEntity)
class TopicEntity: OctoObjectEntity {
    private static let entityName = "Topic"
    @NSManaged public var name: String
    @NSManaged public var desc: String
    @NSManaged public var position: Int
    @NSManaged public var followStatusValue: Int
    @NSManaged public var sectionRelationship: NSSet?

    var sections: [SectionEntity] {
        let sectionSet = sectionRelationship as? Set<SectionEntity> ?? []
        return sectionSet.sorted { $0.position < $1.position }
    }

    func fill(with topic: StorableTopic, position: Int, context: NSManagedObjectContext) throws {
        uuid = topic.uuid
        name = topic.name
        desc = topic.description
        descChildrenFeedId = topic.feedId
        followStatusValue = topic.followStatus.rawValue
        self.position = position
        sectionRelationship = NSSet(array: try topic.sections.map {
            let sectionEntity: SectionEntity
            if let existingSection = try context.fetch(SectionEntity.fetchById(id: $0.uuid)).first {
                sectionEntity = existingSection
            } else {
                sectionEntity = SectionEntity(context: context)
            }
            try sectionEntity.fill(with: $0, context: context)
            return sectionEntity
        })
    }
}

// Extension that adds all fetch requests needed
extension TopicEntity {
    @nonobjc public class func fetchAll() -> NSFetchRequest<TopicEntity> {
        return NSFetchRequest<TopicEntity>(entityName: Self.entityName)
    }

    @nonobjc public class func fetchAllAndSorted() -> NSFetchRequest<TopicEntity> {
        let request = fetchAll()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(TopicEntity.position), ascending: true)]
        return request
    }

    @nonobjc public class func fetchAllForDelete() -> NSFetchRequest<NSFetchRequestResult> {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: Self.entityName)
        request.includesPropertyValues = false
        return request
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<TopicEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(TopicEntity.uuid), id)
        request.fetchLimit = 1
        return request
    }
}
