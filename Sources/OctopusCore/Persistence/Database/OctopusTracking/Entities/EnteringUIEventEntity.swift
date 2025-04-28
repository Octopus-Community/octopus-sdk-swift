//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(EnteringUIEventEntity)
class EnteringUIEventEntity: EventEntity {
    @NSManaged public var firstSession: Bool
}
