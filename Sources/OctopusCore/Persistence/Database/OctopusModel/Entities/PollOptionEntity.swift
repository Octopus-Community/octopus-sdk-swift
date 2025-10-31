//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PollOptionEntity)
class PollOptionEntity: NSManagedObject, Identifiable {
    @NSManaged public var uuid: String
    @NSManaged public var text: String
    @NSManaged public var translatedText: String?
}
