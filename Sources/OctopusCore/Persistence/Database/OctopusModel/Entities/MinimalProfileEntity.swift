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
    @NSManaged public var tagsRawValue: Int
    @NSManaged public var gamificationLevel: Int

    var tags: ProfileTags { ProfileTags(rawValue: tagsRawValue) }

    func fill(with profile: MinimalProfile, replaceSecondaryInfosIfNil: Bool = true,
              context: NSManagedObjectContext) {
        profileId = profile.uuid
        nickname = profile.nickname
        avatarUrl = profile.avatarUrl
        if !profile.tags.isEmpty || replaceSecondaryInfosIfNil {
            tagsRawValue = profile.tags.rawValue
        } // else we do not change tagsRawValue
        if let newGamificationLevel = profile.gamificationLevel {
            gamificationLevel = newGamificationLevel
        } else if replaceSecondaryInfosIfNil {
            gamificationLevel = -1
        } // else we do not change gamification level
    }
}

extension MinimalProfileEntity {
    @nonobjc public class func fetchAll() -> NSFetchRequest<MinimalProfileEntity> {
        return NSFetchRequest<MinimalProfileEntity>(entityName: "MinimalProfile")
    }

    @nonobjc public class func fetchById(id: String) -> NSFetchRequest<MinimalProfileEntity> {
        let request = fetchAll()
        request.predicate = NSPredicate(format: "%K LIKE %@", #keyPath(MinimalProfileEntity.profileId), id)
        request.fetchLimit = 1
        return request
    }
}
