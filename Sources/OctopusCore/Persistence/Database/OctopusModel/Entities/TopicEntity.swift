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
}
