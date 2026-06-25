//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import OctopusCore
@testable import OctopusUI

/// Per-field edit mode on the edit screen, combining the SSO app-managed redirect with the
/// community per-field lock (OCT-1487, Rule 3 + Q4 precedence).
final class EditProfileFieldModeTests: XCTestCase {

    func testAppManagedFieldAlwaysRedirectsRegardlessOfLock() {
        // Q4: appManagedFields wins for that field.
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: true, lock: .editable), .editInApp)
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: true, lock: .readOnly), .editInApp)
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: true, lock: .disabled), .editInApp)
    }

    func testEditableFieldEditsInOctopus() {
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: false, lock: .editable), .editInOctopus)
    }

    func testLockedFieldIsHiddenFromEditScreen() {
        // Rule 3: read-only / disabled fields are not displayed in the edit screen.
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: false, lock: .readOnly), .hidden)
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: false, lock: .disabled), .hidden)
    }
}
