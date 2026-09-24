//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusCore
@testable import OctopusUI

/// Unit-tests for `ScreenStateFailure`, the two shapes a failed first load takes on screen.
///
/// The design only distinguishes "no connection" — which the member can act on — from everything else,
/// so every other error, whatever its origin, has to collapse onto the neutral catch-all rather than
/// leak a network wording (Screen states spec).
@Suite
struct ScreenStateFailureTests {
    @Test func aLostConnectionIsItsOwnCase() {
        #expect(ScreenStateFailure(ServerCallError.noNetwork) == .noNetwork)
        #expect(ScreenStateFailure(AuthenticatedActionError.noNetwork) == .noNetwork)
    }

    @Test func aServerErrorIsTheCatchAll() {
        #expect(ScreenStateFailure(ServerCallError.serverError(.notFound)) == .other)
        #expect(ScreenStateFailure(ServerCallError.other(nil)) == .other)
    }

    @Test func anAuthenticationErrorIsTheCatchAll() {
        // A member who has to log in again still gets the neutral wording: the network is not the issue.
        #expect(ScreenStateFailure(AuthenticatedActionError.userNotAuthenticated) == .other)
    }
}
