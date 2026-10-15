//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import OctopusCore
@testable import OctopusUI

/// The first-post nickname-confirmation gate, including the per-field profile lock and the host app's
/// ownership of the nickname: a community-locked or app-managed nickname is treated as already-confirmed,
/// so the confirmation screen is skipped.
final class ConnectedActionNicknameValidationTests: XCTestCase {

    func testEditableUnconfirmedNicknameStillRequiresValidation() {
        XCTAssertTrue(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: false, nicknameLock: .editable, isNicknameAppManaged: false))
    }

    func testConfirmedNicknameNeverRequiresValidation() {
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: true, nicknameLock: .editable, isNicknameAppManaged: false))
    }

    func testLockedNicknameSkipsValidationEvenWhenUnconfirmed() {
        // A community-locked field is treated as already-confirmed → no confirmation screen.
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: false, nicknameLock: .readOnly, isNicknameAppManaged: false))
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: false, nicknameLock: .disabled, isNicknameAppManaged: false))
    }

    func testAppManagedNicknameSkipsValidationEvenWhenUnconfirmed() {
        // The host app owns the nickname: the member cannot change it in the SDK, so there is nothing to choose.
        for action in [UserAction.post, .comment, .reply] {
            XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
                for: action, hasConfirmedNickname: false, nicknameLock: .editable, isNicknameAppManaged: true))
        }
    }

    func testNonValidatingActionNeverRequiresValidation() {
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .reaction, hasConfirmedNickname: false, nicknameLock: .editable, isNicknameAppManaged: false))
    }
}
