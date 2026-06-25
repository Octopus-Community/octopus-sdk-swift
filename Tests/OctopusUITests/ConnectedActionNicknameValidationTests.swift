//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import OctopusCore
@testable import OctopusUI

/// The first-post nickname-confirmation gate, including the per-field profile lock (OCT-1487, Q5):
/// a community-locked nickname is treated as already-confirmed, so the confirmation screen is skipped.
final class ConnectedActionNicknameValidationTests: XCTestCase {

    func testEditableUnconfirmedNicknameStillRequiresValidation() {
        XCTAssertTrue(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: false, nicknameLock: .editable))
    }

    func testConfirmedNicknameNeverRequiresValidation() {
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: true, nicknameLock: .editable))
    }

    func testLockedNicknameSkipsValidationEvenWhenUnconfirmed() {
        // Q5: a community-locked field is treated as already-confirmed → no confirmation screen.
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: false, nicknameLock: .readOnly))
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .post, hasConfirmedNickname: false, nicknameLock: .disabled))
    }

    func testNonValidatingActionNeverRequiresValidation() {
        XCTAssertFalse(ConnectedActionChecker.needsNicknameValidation(
            for: .reaction, hasConfirmedNickname: false, nicknameLock: .editable))
    }
}
