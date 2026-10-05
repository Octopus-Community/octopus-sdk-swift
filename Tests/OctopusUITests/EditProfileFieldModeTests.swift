//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import OctopusCore
@testable import OctopusUI

/// Per-field edit mode on the edit screen, combining the SSO app-managed redirect with the
/// community per-field lock: a locked field is hidden from the edit screen, but an app-managed field
/// always redirects to the host app, whatever its lock.
final class EditProfileFieldModeTests: XCTestCase {

    func testAppManagedFieldAlwaysRedirectsRegardlessOfLock() {
        // appManagedFields wins over the community lock for that field.
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: true, lock: .editable), .editInApp)
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: true, lock: .readOnly), .editInApp)
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: true, lock: .disabled), .editInApp)
    }

    func testEditableFieldEditsInOctopus() {
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: false, lock: .editable), .editInOctopus)
    }

    func testLockedFieldIsHiddenFromEditScreen() {
        // Read-only / disabled fields are not displayed in the edit screen.
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: false, lock: .readOnly), .hidden)
        XCTAssertEqual(EditProfileViewModel.fieldEditMode(isAppManaged: false, lock: .disabled), .hidden)
    }
}
