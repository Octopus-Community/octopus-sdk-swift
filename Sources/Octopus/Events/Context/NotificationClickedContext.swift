//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .notificationClicked
    public protocol NotificationClickedContext: Sendable {
        /// The id of the notification
        var notificationId: String { get }
        /// The target content id. Can be null if the notification does not target a content.
        var contentId: String? { get }
    }
}

extension SdkEvent.NotificationClickedContext: OctopusEvent.NotificationClickedContext { }
