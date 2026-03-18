//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(DisplayConfigEntity)
class DisplayConfigEntity: NSManagedObject, Identifiable {

    @NSManaged public var poweredByIsHidden: Bool
    @NSManaged public var poweredByLightUrl: URL?
    @NSManaged public var poweredByDarkUrl: URL?

    func fill(with config: DisplayConfig, context: NSManagedObjectContext) {
        switch config.poweredByOctopus {
        case .normal:
            poweredByIsHidden = false
            poweredByLightUrl = nil
            poweredByDarkUrl = nil
        case let .custom(urls):
            poweredByIsHidden = false
            poweredByLightUrl = urls.lightValue
            poweredByDarkUrl = urls.darkValue
        case .hidden:
            poweredByIsHidden = true
            poweredByLightUrl = nil
            poweredByDarkUrl = nil
        }

    }
}
