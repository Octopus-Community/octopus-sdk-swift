//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(CustomEventEntity)
class CustomEventEntity: EventEntity {
    @NSManaged public var name: String
    @NSManaged public var hasProperties: NSSet // Set of CustomEventPropertyEntity

    var properties: [CustomEventPropertyEntity] {
        return Array(hasProperties as? Set<CustomEventPropertyEntity> ?? [])
    }
}

@objc(CustomEventPropertyEntity)
class CustomEventPropertyEntity: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var value: String
}
