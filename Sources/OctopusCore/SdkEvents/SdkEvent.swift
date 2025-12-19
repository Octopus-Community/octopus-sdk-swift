//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// An internal SDK event
public enum SdkEvent: Sendable {
    case contentCreated(content: any OctopusContent)
    case contentDeleted(content: (any OctopusContent)?)
    case contentReactionChanged(content: any OctopusContent, reaction: ReactionKind?)
    case profileUpdated
}
