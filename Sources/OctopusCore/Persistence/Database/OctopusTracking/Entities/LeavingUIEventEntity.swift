//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(LeavingUIEventEntity)
class LeavingUIEventEntity: EventEntity {
    @NSManaged public var startTimestamp: Double
    @NSManaged public var endTimestamp: Double
    @NSManaged public var firstSession: Bool
}
