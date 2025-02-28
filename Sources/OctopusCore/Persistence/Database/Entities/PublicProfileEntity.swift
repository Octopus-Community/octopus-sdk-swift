//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PublicProfileEntity)
class PublicProfileEntity: NSManagedObject, Identifiable {
    @NSManaged public var profileId: String
    @NSManaged public var nickname: String?
    @NSManaged public var bio: String?
    @NSManaged public var pictureUrl: URL?
    @NSManaged public var descPostFeedId: String
    @NSManaged public var ascPostFeedId: String

    @nonobjc public class func fetchAll() -> NSFetchRequest<PublicProfileEntity> {
        return NSFetchRequest<PublicProfileEntity>(entityName: "PublicProfile")
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<PublicProfileEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(PublicProfileEntity.profileId), id)
        request.fetchLimit = 1
        return request
    }
}
