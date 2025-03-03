//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import KeychainAccess
import DependencyInjection

extension Injected {
    static let userDataStorage = Injector.InjectedIdentifier<UserDataStorage>()
}

class UserDataStorage: InjectableObject {
    static let injectedIdentifier = Injected.userDataStorage

    struct UserData: Equatable {
        let id: String
        let clientId: String?
        let jwtToken: String

        init(id: String, clientId: String? = nil, jwtToken: String) {
            self.id = id
            self.clientId = clientId
            self.jwtToken = jwtToken
        }
    }

    struct ClientUserData: Equatable {
        let id: String
        let token: String?
    }

    struct MagicLinkData: Equatable {
        let magicLinkId: String
        let email: String
    }

    private enum UserKeys {
        static let base = "user"
        static let id = "\(base)_id"
        static let clientId = "\(base)_clientId"
        static let jwtToken = "\(base)_jwtToken"
    }

    private enum ClientUserKeys {
        static let base = "client_user"
        static let id = "\(base)_id"
        static let token = "\(base)_token"
    }

    private struct MagicLinkKeys {
        static let base = "magicLink"
        static let identifier = "\(base)_id"
        static let email = "\(base)_email"
    }

    @Published private(set) var userData: UserData?
    @Published private(set) var clientUserData: ClientUserData?
    @Published private(set) var magicLinkData: MagicLinkData?

    private let securedStorage: SecuredStorage

    init(injector: Injector) {
        securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage)

        if let id = securedStorage[UserKeys.id], let token = securedStorage[UserKeys.jwtToken] {
            let clientId = securedStorage[UserKeys.clientId]
            userData = UserData(id: id, clientId: clientId, jwtToken: token)
        }

        if let id = securedStorage[ClientUserKeys.id] {
            let token = securedStorage[ClientUserKeys.token]
            clientUserData = ClientUserData(id: id, token: token)
        }

        if let magicLinkId = securedStorage[MagicLinkKeys.identifier], let email = securedStorage[MagicLinkKeys.email] {
            magicLinkData = MagicLinkData(magicLinkId: magicLinkId, email: email)
        }
    }
    
    func store(userData: UserData?) {
        securedStorage[UserKeys.id] = userData?.id
        securedStorage[UserKeys.jwtToken] = userData?.jwtToken

        self.userData = userData
    }

    func store(clientUserData: ClientUserData?) {
        securedStorage[ClientUserKeys.id] = clientUserData?.id
        securedStorage[ClientUserKeys.token] = clientUserData?.token

        self.clientUserData = clientUserData
    }

    func store(magicLinkData: MagicLinkData?) {
        securedStorage[MagicLinkKeys.identifier] = magicLinkData?.magicLinkId
        securedStorage[MagicLinkKeys.email] = magicLinkData?.email

        self.magicLinkData = magicLinkData
    }
}
