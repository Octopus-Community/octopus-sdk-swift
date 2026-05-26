//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// State of a Post / Comment / Reply with respect to the current user's access
/// and write permissions.
///
/// Derived from `permissions.canAccess` / `permissions.canCreateChildren` and the
/// comparison of the content's author to the current user. Used by detail-view
/// ViewModels to decide between rendering normally, rendering body without
/// children (own content), rendering the existing not-available empty state,
/// or rendering body + children but hiding the compose affordance.
public enum LockedContentState: Equatable, Sendable {
    /// `permissions.canAccess == true && permissions.canCreateChildren == true` — render normally.
    case unlocked
    /// `permissions.canAccess == false` AND the content's author is the current user.
    /// Render the body, hide the children feed, and hide the write input.
    case lockedOwnContent
    /// `permissions.canAccess == false` AND the content's author is someone else (or
    /// unknown — author nil, current user nil, deleted). Render the existing
    /// "not available" empty state.
    case lockedOther
    /// `permissions.canAccess == true && permissions.canCreateChildren == false`.
    /// Body and existing children render normally; the compose affordance is hidden.
    case composeLocked

    /// Derives the locked state from a content item's permissions and whether the
    /// content's author is the current user.
    ///
    /// `isOwnContent` is only consulted when `canAccess == false`: own content keeps
    /// reading rights (`.lockedOwnContent`), other-user content is hidden (`.lockedOther`).
    /// When `canAccess == true`, authorship doesn't affect the state.
    public init(permissions: UserPermissions, isOwnContent: Bool) {
        if permissions.canAccess {
            self = permissions.canCreateChildren ? .unlocked : .composeLocked
        } else if isOwnContent {
            self = .lockedOwnContent
        } else {
            self = .lockedOther
        }
    }
}
