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
    @NSManaged public var originalNickname: String?
    @NSManaged public var email: String?
    @NSManaged public var bio: String?
    @NSManaged public var pictureUrl: URL?
    @NSManaged public var descPostFeedId: String
    @NSManaged public var ascPostFeedId: String
    @NSManaged public var notificationBadgeCount: Int
    @NSManaged public var blocking: NSOrderedSet
    @NSManaged public var hasSeenOnboardingOptional: NSNumber?
    @NSManaged public var hasAcceptedCguOptional: NSNumber?
    @NSManaged public var hasConfirmedNicknameOptional: NSNumber?
    @NSManaged public var hasConfirmedBioOptional: NSNumber?
    @NSManaged public var hasConfirmedPictureOptional: NSNumber?
    @NSManaged public var isGuest: Bool

    var hasSeenOnboarding: Bool? { hasSeenOnboardingOptional?.boolValue }
    var hasAcceptedCgu: Bool? { hasAcceptedCguOptional?.boolValue }
    var hasConfirmedNickname: Bool? { hasConfirmedNicknameOptional?.boolValue }
    var hasConfirmedBio: Bool? { hasConfirmedBioOptional?.boolValue }
    var hasConfirmedPicture: Bool? { hasConfirmedPictureOptional?.boolValue }

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
