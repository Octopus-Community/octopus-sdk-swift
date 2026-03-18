//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(SectionEntity)
class SectionEntity: OctoObjectEntity {
    private static let entityName = "Section"
    @NSManaged public var name: String
    @NSManaged public var position: Int
    @NSManaged public var topicRelationship: NSSet?

    var topics: [TopicEntity] {
        let topicSet = topicRelationship as? Set<TopicEntity> ?? []
        return topicSet.sorted { $0.position < $1.position }
    }

    func fill(with section: StorableSection, context: NSManagedObjectContext) throws {
        uuid = section.uuid
        name = section.name
        position = section.position
    }
}

extension SectionEntity {
    @nonobjc public class func fetchAll() -> NSFetchRequest<SectionEntity> {
        return NSFetchRequest<SectionEntity>(entityName: Self.entityName)
    }

    @nonobjc public class func fetchAllAndSorted() -> NSFetchRequest<SectionEntity> {
        let request = fetchAll()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(SectionEntity.position), ascending: true)]
        return request
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<SectionEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(SectionEntity.uuid), id)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchAllForDelete() -> NSFetchRequest<NSFetchRequestResult> {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: Self.entityName)
        request.includesPropertyValues = false
        return request
    }
}
