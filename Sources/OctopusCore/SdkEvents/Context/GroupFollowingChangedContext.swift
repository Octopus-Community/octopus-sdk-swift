//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import os

extension SdkEvent {
    public struct GroupFollowingChangedContext: Sendable {
        /// The group that is concerned by this change
        public let groupId: String
        /// Whether the user has followed or unfollowed this group
        public let followed: Bool
    }
}
