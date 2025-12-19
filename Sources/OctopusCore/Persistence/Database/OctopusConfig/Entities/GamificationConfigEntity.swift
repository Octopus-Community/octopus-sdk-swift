//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(GamificationConfigEntity)
class GamificationConfigEntity: NSManagedObject, Identifiable {

    @NSManaged public var pointsName: String
    @NSManaged public var abbrevPointPlural: String
    @NSManaged public var abbrevPointSingular: String
    @NSManaged public var commentOnYourPostPts: Int
    @NSManaged public var commentPts: Int
    @NSManaged public var completeProfilePts: Int
    @NSManaged public var loginPts: Int
    @NSManaged public var postPts: Int
    @NSManaged public var reactPts: Int
    @NSManaged public var replyPts: Int
    @NSManaged public var votePts: Int
    @NSManaged public var gamificationLevelsRelationship: NSOrderedSet

    var gamificationLevels: [GamificationLevelEntity] {
        gamificationLevelsRelationship.array as? [GamificationLevelEntity] ?? []
    }

    func fill(with config: GamificationConfig, context: NSManagedObjectContext) {
        pointsName = config.pointsName
        abbrevPointPlural = config.abbrevPointPlural
        abbrevPointSingular = config.abbrevPointSingular
        commentOnYourPostPts = config.pointsByAction[.postCommented] ?? -1
        commentPts = config.pointsByAction[.comment] ?? -1
        completeProfilePts = config.pointsByAction[.profileCompleted] ?? -1
        loginPts = config.pointsByAction[.dailySession] ?? -1
        postPts = config.pointsByAction[.post] ?? -1
        reactPts = config.pointsByAction[.reaction] ?? -1
        replyPts = config.pointsByAction[.reply] ?? -1
        votePts = config.pointsByAction[.vote] ?? -1

        gamificationLevelsRelationship = NSOrderedSet(array: config.gamificationLevels.map {
            let levelEntity = GamificationLevelEntity(context: context)
            levelEntity.fill(with: $0, context: context)
            return levelEntity
        })
    }
}
