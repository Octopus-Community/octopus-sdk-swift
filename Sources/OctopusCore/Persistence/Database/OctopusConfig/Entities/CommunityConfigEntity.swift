//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(CommunityConfigEntity)
class CommunityConfigEntity: NSManagedObject, Identifiable {
    @NSManaged public var forceLoginOnStrongActions: Bool
    @NSManaged public var displayAccountAge: Bool
    @NSManaged public var gamificationConfig: GamificationConfigEntity?

    func fill(with config: CommunityConfig, context: NSManagedObjectContext) {
        forceLoginOnStrongActions = config.forceLoginOnStrongActions
        displayAccountAge = config.displayAccountAge
        gamificationConfig = config.gamificationConfig.map { gamificationConfig in
            let entity = GamificationConfigEntity(context: context)
            entity.fill(with: gamificationConfig, context: context)
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
