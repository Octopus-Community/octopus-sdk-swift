//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(BridgePostOpenedEventEntity)
class BridgePostOpenedEventEntity: EventEntity {
    @NSManaged public var success: Bool
}
