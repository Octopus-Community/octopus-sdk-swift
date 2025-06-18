//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(NotificationSettingsEntity)
class NotificationSettingsEntity: NSManagedObject, Identifiable {
    @NSManaged public var pushNotificationsEnabled: Bool

    @nonobjc public class func fetchOne() -> NSFetchRequest<NotificationSettingsEntity> {
        let request = NSFetchRequest<NotificationSettingsEntity>(entityName: "NotificationSettings")
        request.fetchLimit = 1
        return request
    }
}
