//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import OctopusCore
@testable import OctopusUI

/// Derived per-field editability for the current-user profile UI (OCT-1487, Q2/Q4).
final class ProfileFieldsEditabilityTests: XCTestCase {

    func testAllEditableShowsEverything() {
        let editability = ProfileFieldsEditability(lock: .allEditable)

        XCTAssertTrue(editability.nicknameEditable)
        XCTAssertTrue(editability.avatarEditable)
        XCTAssertTrue(editability.bioEditable)
        XCTAssertFalse(editability.bioHidden)
        XCTAssertTrue(editability.showEditButton)
    }

    func testClueConfigLocksEverythingAndHidesEditButton() {
        // Clue: pseudo read-only + avatar read-only + bio disabled.
        let lock = ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .disabled)
        let editability = ProfileFieldsEditability(lock: lock)

        XCTAssertFalse(editability.nicknameEditable)
        XCTAssertFalse(editability.avatarEditable)
        XCTAssertFalse(editability.bioEditable)
        XCTAssertTrue(editability.bioHidden)
        XCTAssertFalse(editability.showEditButton)
    }

    func testEditButtonVisibleWhenOnlyBioEditable() {
        // Q2: the "Edit profile" button keys off all three fields, including bio.
        let lock = ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .editable)
        let editability = ProfileFieldsEditability(lock: lock)

        XCTAssertTrue(editability.showEditButton)
        XCTAssertFalse(editability.bioHidden)
    }

    func testReadOnlyBioIsNotHiddenAndNotEditable() {
        let lock = ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .readOnly)
        let editability = ProfileFieldsEditability(lock: lock)

        XCTAssertFalse(editability.bioEditable)
        XCTAssertFalse(editability.bioHidden)
        XCTAssertFalse(editability.showEditButton)
    }
}
