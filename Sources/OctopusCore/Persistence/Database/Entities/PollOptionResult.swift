//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PollOptionResultEntity)
class PollOptionResultEntity: NSManagedObject, Identifiable {
    @NSManaged public var optionId: String
    @NSManaged public var voteCount: Int
}
