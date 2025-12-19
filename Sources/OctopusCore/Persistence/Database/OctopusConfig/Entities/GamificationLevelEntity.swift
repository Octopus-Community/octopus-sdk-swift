//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(GamificationLevelEntity)
class GamificationLevelEntity: NSManagedObject, Identifiable {
    @NSManaged public var level: Int
    @NSManaged public var name: String
    @NSManaged public var nextLevelAtOptional: NSNumber?
    @NSManaged public var badgeLightColorHex: String?
    @NSManaged public var badgeDarkColorHex: String?
    @NSManaged public var badgeTextLightColorHex: String?
    @NSManaged public var badgeTextDarkColorHex: String?

    public var nextLevelAt: Int? { nextLevelAtOptional?.intValue }

    func fill(with level: GamificationLevel, context: NSManagedObjectContext) {
        self.level = level.level
        name = level.name
        nextLevelAtOptional = level.nextLevelAt.map { NSNumber(value: $0) }
        badgeLightColorHex = level.badgeColor?.hexLight
        badgeDarkColorHex = level.badgeColor?.hexDark
        badgeTextLightColorHex = level.badgeTextColor?.hexLight
        badgeTextDarkColorHex = level.badgeTextColor?.hexDark
    }
}
