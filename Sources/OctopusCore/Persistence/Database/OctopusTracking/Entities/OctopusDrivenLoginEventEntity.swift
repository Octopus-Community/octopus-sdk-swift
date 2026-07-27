//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(OctopusDrivenLoginEventEntity)
class OctopusDrivenLoginEventEntity: EventEntity {
    /// The triggering action, stored as `OctopusDrivenLoginAction.rawValue`.
    @NSManaged public var action: String
}
