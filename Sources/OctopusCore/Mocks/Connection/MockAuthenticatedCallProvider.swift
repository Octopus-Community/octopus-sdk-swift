//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection
import OctopusRemoteClient

class MockAuthenticatedCallProvider: AuthenticatedCallProvider, InjectableObject {
    static let injectedIdentifier = Injected.authenticatedCallProvider
    var isConnected: Bool = true

    func authenticatedMethod() throws(AuthenticatedActionError) -> AuthenticationMethod {
        guard isConnected else { throw .userNotAuthenticated }
        return .authenticated(token: "fake_token", authFailure: { })
    }

    func authenticatedMethod(forceJwt: String) throws(AuthenticatedActionError) -> AuthenticationMethod {
        guard isConnected else { throw .userNotAuthenticated }
        return .authenticated(token: forceJwt, authFailure: { })
    }

    func authenticatedIfPossibleMethod() -> AuthenticationMethod {
        guard isConnected else { return .notAuthenticated }
        return .authenticated(token: "fake_token", authFailure: { })
    }
}
