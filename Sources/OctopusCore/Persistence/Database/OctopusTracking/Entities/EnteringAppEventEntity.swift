//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(EnteringAppEventEntity)
class EnteringAppEventEntity: EventEntity {
    @NSManaged public var firstSession: Bool
}
