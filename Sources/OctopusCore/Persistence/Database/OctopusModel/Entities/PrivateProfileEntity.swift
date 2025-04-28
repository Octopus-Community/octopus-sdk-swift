//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PrivateProfileEntity)
class PrivateProfileEntity: NSManagedObject, Identifiable {
    @NSManaged public var profileId: String
    @NSManaged public var userId: String
    @NSManaged public var nickname: String
    @NSManaged public var email: String?
    @NSManaged public var bio: String?
    @NSManaged public var pictureUrl: URL?
    @NSManaged public var descPostFeedId: String
    @NSManaged public var ascPostFeedId: String
    @NSManaged public var blocking: NSOrderedSet

    var blockedProfileIds: [String] {
        (blocking.array as? [BlockedUserEntity] ?? []).map { $0.profileId }
    }

    @nonobjc public class func fetchAll() -> NSFetchRequest<PrivateProfileEntity> {
        return NSFetchRequest<PrivateProfileEntity>(entityName: "PrivateProfile")
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<PrivateProfileEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(PrivateProfileEntity.profileId), id)
        request.fetchLimit = 1
        return request
    }

    @nonobjc public class func fetchByUserId(userId: String) -> NSFetchRequest<PrivateProfileEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(PrivateProfileEntity.userId), userId)
        request.fetchLimit = 1
        return request
    }
}
