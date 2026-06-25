//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// Derived, per-field editability for the current-user profile UI, computed from the community
/// per-field lock (OCT-1487). Drives which affordances the profile/edit screens display.
///
/// This is the community-config lock only; the SSO `appManagedFields` redirect is handled
/// separately (and wins per field — see PRD Q4). With `.allEditable` every flag is `true`, so the
/// UI is strictly identical to today for every community that sets no lock.
struct ProfileFieldsEditability: Equatable {
    let nicknameEditable: Bool
    let avatarEditable: Bool
    let bioEditable: Bool
    /// Bio is `disabled`: no bio section at all (no display even of an existing value, no "Add a bio").
    let bioHidden: Bool

    init(lock: ProfileFieldsLock) {
        nicknameEditable = lock.nickname == .editable
        avatarEditable = lock.avatar == .editable
        bioEditable = lock.bio == .editable
        bioHidden = lock.bio == .disabled
    }

    /// The "Edit profile" button is shown as soon as at least one of the three fields is editable
    /// (Q2: keys off nickname / avatar / bio).
    var showEditButton: Bool { nicknameEditable || avatarEditable || bioEditable }
}
