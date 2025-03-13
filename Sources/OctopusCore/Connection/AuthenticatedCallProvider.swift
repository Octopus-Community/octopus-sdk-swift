//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import os
import RemoteClient
import DependencyInjection

protocol AuthenticatedCallProvider {
    func authenticatedMethod() throws(AuthenticatedActionError) -> AuthenticationMethod
    func authenticatedIfPossibleMethod() -> AuthenticationMethod
}

extension Injected {
    static let authenticatedCallProvider = Injector.InjectedIdentifier<AuthenticatedCallProvider>()
}

class AuthenticatedCallProviderDefault: AuthenticatedCallProvider, InjectableObject {
    static let injectedIdentifier = Injected.authenticatedCallProvider

    private let injector: Injector
    private let userDataStorage: UserDataStorage
    private lazy var connectionRepository: ConnectionRepository = {
        injector.getInjected(identifiedBy: Injected.connectionRepository)
    }()

    init(injector: Injector) {
        self.injector = injector
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
    }

    func authenticatedMethod() throws(AuthenticatedActionError) -> AuthenticationMethod {
        guard let userData = userDataStorage.userData else {
            throw .userNotAuthenticated
        }
        return .authenticated(
            token: userData.jwtToken,
            authFailure: { [weak self] in
                guard let self else { return }
                if #available(iOS 14, *) { Logger.connection.debug("Authentication error received from server, logging out the user") }
                let connectionRepository = self.connectionRepository
                Task {
                    try await connectionRepository.logout()
                }
            })
    }

    func authenticatedIfPossibleMethod() -> AuthenticationMethod {
        guard let userData = userDataStorage.userData else {
            return .notAuthenticated
        }
        return .authenticated(
            token: userData.jwtToken,
            authFailure: { [weak self] in
                guard let self else { return }
                if #available(iOS 14, *) { Logger.connection.debug("Authentication error received from server, logging out the user") }
                let connectionRepository = self.connectionRepository
                Task {
                    try await connectionRepository.logout()
                }
            })
    }
}
