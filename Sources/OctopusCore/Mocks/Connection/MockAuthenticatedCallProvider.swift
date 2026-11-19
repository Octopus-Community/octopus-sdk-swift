//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection
import OctopusRemoteClient

class MockAuthenticatedCallProvider: AuthenticatedCallProvider, InjectableObject {
    static let injectedIdentifier = Injected.authenticatedCallProvider
    var isConnected: Bool = true
    /// The token of the authenticated methods, that a test can change to simulate a token rotation.
    var token = "fake_token"
    /// The user of the session while `isConnected`, that a test can change to simulate a new session.
    var userId = "fake_user_id"

    var sessionUserId: String? { isConnected ? userId : nil }

    func authenticatedMethod() throws(AuthenticatedActionError) -> AuthenticationMethod {
        guard isConnected else { throw .userNotAuthenticated }
        return .authenticated(token: token, authFailure: { })
    }

    func authenticatedMethod(forceJwt: String) throws(AuthenticatedActionError) -> AuthenticationMethod {
        guard isConnected else { throw .userNotAuthenticated }
        return .authenticated(token: forceJwt, authFailure: { })
    }

    func authenticatedIfPossibleMethod() -> AuthenticationMethod {
        guard isConnected else { return .notAuthenticated }
        return .authenticated(token: token, authFailure: { })
    }
}
