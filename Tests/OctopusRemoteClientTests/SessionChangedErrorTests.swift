//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusRemoteClient

/// A response that comes back after the session changed is refused by `RefreshingTokenInterceptor`; callers need to
/// tell that refusal apart from the other failures to send the call again with the new session.
struct SessionChangedErrorTests {
    @Test func refusalOfAResponseForAnotherSessionIsRecognized() {
        let error = RemoteClientError(error: RefreshingTokenError.userIdNotMatching)

        #expect(error.isSessionChangedDuringCall)
    }

    @Test(arguments: [
        RemoteClientError.timeout, .cancelled, .notFound, .notAuthenticated(reason: nil),
        .permissionDenied(reason: nil), .unknown(CocoaError(.featureUnsupported))
    ])
    func otherFailuresAreNotTakenForASessionChange(error: RemoteClientError) {
        #expect(!error.isSessionChangedDuringCall)
    }
}
