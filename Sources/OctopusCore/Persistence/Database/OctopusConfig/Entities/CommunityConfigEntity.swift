//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(CommunityConfigEntity)
class CommunityConfigEntity: NSManagedObject, Identifiable {
    @NSManaged public var forceLoginOnStrongActions: Bool
    @NSManaged public var displayAccountAge: Bool
    @NSManaged public var nicknameLock: Int16
    @NSManaged public var avatarLock: Int16
    @NSManaged public var bioLock: Int16
    @NSManaged public var postEnablePictures: Bool
    @NSManaged public var postEnablePolls: Bool
    @NSManaged public var commentEnablePictures: Bool
    @NSManaged public var replyEnablePictures: Bool
    @NSManaged public var gamificationConfig: GamificationConfigEntity?
    @NSManaged public var displayConfig: DisplayConfigEntity?

    func fill(with config: CommunityConfig, context: NSManagedObjectContext) {
        forceLoginOnStrongActions = config.forceLoginOnStrongActions
        displayAccountAge = config.displayAccountAge
        nicknameLock = config.profileFieldsLock.nickname.storageValue
        avatarLock = config.profileFieldsLock.avatar.storageValue
        bioLock = config.profileFieldsLock.bio.storageValue
        postEnablePictures = config.contentOptions.post.enablePictures
        postEnablePolls = config.contentOptions.post.enablePolls
        commentEnablePictures = config.contentOptions.comment.enablePictures
        replyEnablePictures = config.contentOptions.reply.enablePictures
        gamificationConfig = config.gamificationConfig.map { gamificationConfig in
            let entity = GamificationConfigEntity(context: context)
            entity.fill(with: gamificationConfig, context: context)
            return entity
        }
        displayConfig = config.displayConfig.map { displayConfig in
            let entity = DisplayConfigEntity(context: context)
            entity.fill(with: displayConfig, context: context)
            return entity
        }
    }
}

// Extension that adds all fetch requests needed
extension CommunityConfigEntity {
    @nonobjc public class func fetch() -> NSFetchRequest<CommunityConfigEntity> {
        let request = NSFetchRequest<CommunityConfigEntity>(entityName: "CommunityConfig")
        request.fetchLimit = 1
        return request
    }
}
