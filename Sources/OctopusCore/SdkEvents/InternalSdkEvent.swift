//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// An internal SDK event
public enum InternalSdkEvent: Sendable {
    case contentCreated(content: any OctopusContent)
    case contentDeleted(content: (any OctopusContent)?)
    case contentReactionChanged(content: any OctopusContent, reaction: ReactionKind?)
    case profileUpdated
    case groupFollowingChanged
    case entitlementsChanged
    /// The content cached for the previous session was deleted, or by a closure of the community that has since
    /// reopened, or it was loaded while there was no session at all: what is on screen has to be loaded again.
    case userContentCleared
}
