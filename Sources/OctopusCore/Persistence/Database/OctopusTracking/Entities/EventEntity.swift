//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(EventEntity)
class EventEntity: NSManagedObject, Identifiable {
    @NSManaged public var uuid: String
    @NSManaged public var timestamp: Double
    @NSManaged public var appSessionId: String?
    @NSManaged public var uiSessionId: String?
    @NSManaged public var sendingAttempts: Int16

    @discardableResult
    static func create(from event: Event, context: NSManagedObjectContext) -> EventEntity {
        let entity: EventEntity
        switch event.content {
        case let .enteringApp(firstSession):
            let specializedEntity = EnteringAppEventEntity(context: context)
            specializedEntity.firstSession = firstSession
            entity = specializedEntity
        case let .leavingApp(startDate, endDate, firstSession):
            let specializedEntity = LeavingAppEventEntity(context: context)
            specializedEntity.startTimestamp = startDate.timeIntervalSince1970
            specializedEntity.endTimestamp = endDate.timeIntervalSince1970
            specializedEntity.firstSession = firstSession
            entity = specializedEntity
        case let .enteringUI(firstSession):
            let specializedEntity = EnteringUIEventEntity(context: context)
            specializedEntity.firstSession = firstSession
            entity = specializedEntity
        case let .leavingUI(startDate, endDate, firstSession):
            let specializedEntity = LeavingUIEventEntity(context: context)
            specializedEntity.startTimestamp = startDate.timeIntervalSince1970
            specializedEntity.endTimestamp = endDate.timeIntervalSince1970
            specializedEntity.firstSession = firstSession
            entity = specializedEntity
        case let .custom(customEvent):
            let specializedEntity = CustomEventEntity(context: context)
            specializedEntity.name = customEvent.name
            specializedEntity.hasProperties = NSSet(array: customEvent.properties.map {
                let property = CustomEventPropertyEntity(context: context)
                property.name = $0.key
                property.value = $0.value.value
                return property
            })
            entity = specializedEntity
        }
        entity.uuid = event.uuid
        entity.timestamp = event.date.timeIntervalSince1970
        entity.appSessionId = event.appSessionId
        entity.uiSessionId = event.uiSessionId
        return entity
    }
}

// Extension that adds all fetch requests needed
extension EventEntity {
    @nonobjc public class func fetchAllByIds(ids: [String]) -> NSFetchRequest<EventEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(EventEntity.uuid), ids)
        return request
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<EventEntity> {
        return NSFetchRequest<EventEntity>(entityName: "Event")
    }
}
