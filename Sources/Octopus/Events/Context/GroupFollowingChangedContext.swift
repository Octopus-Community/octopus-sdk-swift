//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .groupFollowingChanged
    public protocol GroupFollowingChangedContext: Sendable {
        /// The group that is concerned by this change
        var groupId: String { get }
        /// Whether the user has followed or unfollowed this group
        var followed: Bool { get }
    }
}

extension SdkEvent.GroupFollowingChangedContext: OctopusEvent.GroupFollowingChangedContext { }
