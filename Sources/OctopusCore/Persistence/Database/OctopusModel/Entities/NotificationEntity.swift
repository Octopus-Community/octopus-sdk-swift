//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(NotificationEntity)
class NotificationEntity: NSManagedObject, Identifiable {
    @NSManaged public var uuid: String
    @NSManaged public var position: Int
    @NSManaged public var updateTimestamp: Double

    @NSManaged public var isRead: Bool
    @NSManaged public var text: String

    @NSManaged public var openAction: String?

    @NSManaged public var thumbnailsRelationship: NSOrderedSet?

    var thumbnails: [MinimalProfileEntity] {
        thumbnailsRelationship?.array as? [MinimalProfileEntity] ?? []
    }

    @nonobjc public class func fetchAllSorted() -> NSFetchRequest<NotificationEntity> {
        let request = fetchAll()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(NotificationEntity.position), ascending: true)]
        return request
    }

    @nonobjc public class func fetchAllByIds(ids: [String]) -> NSFetchRequest<NotificationEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(NotificationEntity.uuid), ids)
        return request
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<NotificationEntity> {
        return NSFetchRequest<NotificationEntity>(entityName: "Notification")
    }
}
