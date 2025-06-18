//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// Notification settings
public struct NotificationSettings: Sendable {
    public static let defaultValue = NotificationSettings(pushNotificationsEnabled: true)

    /// Whether Octopus Community push notifications are enabled by user
    public let pushNotificationsEnabled: Bool

    public init(pushNotificationsEnabled: Bool) {
        self.pushNotificationsEnabled = pushNotificationsEnabled
    }
}

extension NotificationSettings {
    init(from entity: NotificationSettingsEntity) {
        pushNotificationsEnabled = entity.pushNotificationsEnabled
    }

    init(from response: Com_Octopuscommunity_NotificationSettingsResponse) {
        pushNotificationsEnabled = response.settings.pushNotificationEnabled
    }
}
