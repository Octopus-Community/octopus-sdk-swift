//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(CommunityConfigEntity)
class CommunityConfigEntity: NSManagedObject, Identifiable {
    @NSManaged public var forceLoginOnStrongActionsOptional: NSNumber?

    var forceLoginOnStrongActions: Bool? { forceLoginOnStrongActionsOptional?.boolValue }

    func fill(with config: CommunityConfig, context: NSManagedObjectContext) {
        forceLoginOnStrongActionsOptional = NSNumber(booleanLiteral: config.forceLoginOnStrongActions)
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
