//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(RootFeedEntity)
class RootFeedEntity: NSManagedObject, Identifiable {

    @NSManaged public var uuid: String
    @NSManaged public var label: String
    @NSManaged public var relatedTopicId: String?
    @NSManaged public var position: Int

    @nonobjc public class func fetchAllSorted() -> NSFetchRequest<RootFeedEntity> {
        let request = fetchAll()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(RootFeedEntity.position), ascending: true)]
        return request
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<RootFeedEntity> {
        return NSFetchRequest<RootFeedEntity>(entityName: "RootFeed")
    }
}
