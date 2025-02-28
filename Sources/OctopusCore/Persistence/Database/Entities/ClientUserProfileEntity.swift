//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(ClientUserProfileEntity)
class ClientUserProfileEntity: NSManagedObject, Identifiable {
    enum AgeInformation: Int16 {
        case unknown
        case legalAgeReached
        case underaged
    }
    @NSManaged public var nickname: String?
    @NSManaged public var bio: String?
    @NSManaged public var picture: Data?
    @NSManaged public var ageInformationValue: Int16

    var ageInformation: AgeInformation { AgeInformation(rawValue: ageInformationValue) ?? .unknown }
}
