//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(ContentReactionEntity)
class ContentReactionEntity: NSManagedObject, Identifiable {
    @NSManaged public var reactionKind: String
    @NSManaged public var count: Int
}
