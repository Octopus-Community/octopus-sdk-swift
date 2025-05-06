//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(MinimalProfileEntity)
class MinimalProfileEntity: NSManagedObject, Identifiable {
    @NSManaged public var profileId: String
    @NSManaged public var nickname: String
    @NSManaged public var avatarUrl: URL?
}
