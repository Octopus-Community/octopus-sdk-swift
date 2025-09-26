//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(ClientUserProfileEntity)
class ClientUserProfileEntity: NSManagedObject, Identifiable {
    @NSManaged public var nickname: String?
    @NSManaged public var bio: String?
    @NSManaged public var picture: Data?
}
