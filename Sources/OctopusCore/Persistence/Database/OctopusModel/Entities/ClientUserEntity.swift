//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(ClientUserEntity)
class ClientUserEntity: NSManagedObject {
    @NSManaged public var clientUserId: String
    @NSManaged public var profile: ClientUserProfileEntity?

    @nonobjc public class func fetchByClientUserId(_ id: String) -> NSFetchRequest<ClientUserEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(ClientUserEntity.clientUserId), id)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<ClientUserEntity> {
        return NSFetchRequest<ClientUserEntity>(entityName: "ClientUser")
    }
}
