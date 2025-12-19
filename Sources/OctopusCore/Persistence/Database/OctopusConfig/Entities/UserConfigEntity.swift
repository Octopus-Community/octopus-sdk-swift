//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(UserConfigEntity)
class UserConfigEntity: NSManagedObject, Identifiable {
    @NSManaged public var canAccessCommunityOptional: NSNumber?
    @NSManaged public var accessDeniedMessage: String?

    var canAccessCommunity: Bool? { canAccessCommunityOptional?.boolValue }

    func fill(canAccessCommunity: Bool, message: String?, context: NSManagedObjectContext) {
        canAccessCommunityOptional = NSNumber(booleanLiteral: canAccessCommunity)
        accessDeniedMessage = message
    }
}

// Extension that adds all fetch requests needed
extension UserConfigEntity {
    @nonobjc public class func fetch() -> NSFetchRequest<UserConfigEntity> {
        let request = NSFetchRequest<UserConfigEntity>(entityName: "UserConfig")
        request.fetchLimit = 1
        return request
    }
}
