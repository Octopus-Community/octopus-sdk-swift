//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(BlockedUserEntity)
class BlockedUserEntity: NSManagedObject, Identifiable {
    @NSManaged public var profileId: String
}
