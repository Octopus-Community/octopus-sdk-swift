//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(ClientSetABTestEventEntity)
class ClientSetABTestEventEntity: EventEntity {
    @NSManaged public var hasAccessToCommunity: Bool
}
