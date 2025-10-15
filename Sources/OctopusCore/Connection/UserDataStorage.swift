//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import KeychainAccess
import OctopusDependencyInjection
import os

extension Injected {
    static let userDataStorage = Injector.InjectedIdentifier<UserDataStorage>()
}

final class UserDataStorage: InjectableObject, @unchecked Sendable {
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
            clientUserData = ClientUserData(id: id)
        }

        if let magicLinkId = securedStorage[MagicLinkKeys.identifier], let email = securedStorage[MagicLinkKeys.email] {
            magicLinkData = MagicLinkData(magicLinkId: magicLinkId, email: email)
        }
    }
    
    func store(userData: UserData?) {
        do {
            try securedStorage.set(userData?.id, key: UserKeys.id)
            try securedStorage.set(userData?.jwtToken, key: UserKeys.jwtToken)
            try securedStorage.set(userData?.clientId, key: UserKeys.clientId)

            self.userData = userData
        } catch {
            if #available(iOS 14, *) { Logger.connection.debug("Error while storing userData: \(error)") }
            // rollback the changes
            do {
                let rollbackUserData = self.userData
                try securedStorage.set(rollbackUserData?.id, key: UserKeys.id)
                try securedStorage.set(rollbackUserData?.jwtToken, key: UserKeys.jwtToken)
                try securedStorage.set(rollbackUserData?.clientId, key: UserKeys.clientId)
            } catch {
                if #available(iOS 14, *) { Logger.connection.debug("Error again while storing userData: \(error)") }
                // if rollback did not work, retry the rollback with a delay
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let rollbackUserData = self.userData
                    do {
                        try securedStorage.set(rollbackUserData?.id, key: UserKeys.id)
                        try securedStorage.set(rollbackUserData?.jwtToken, key: UserKeys.jwtToken)
                        try securedStorage.set(rollbackUserData?.clientId, key: UserKeys.clientId)
                    } catch {
                        if #available(iOS 14, *) { Logger.connection.debug("Error again again while storing userData: \(error)") }
                    }
                }
            }
        }
    }

    func store(clientUserData: ClientUserData?) {
        do {
            try securedStorage.set(clientUserData?.id, key: ClientUserKeys.id)

            self.clientUserData = clientUserData
        } catch {
            if #available(iOS 14, *) { Logger.connection.debug("Error while storing client user data: \(error)") }
        }
    }

    func store(magicLinkData: MagicLinkData?) {
        do {
            try securedStorage.set(magicLinkData?.magicLinkId, key: MagicLinkKeys.identifier)
            try securedStorage.set(magicLinkData?.email, key: MagicLinkKeys.email)

            self.magicLinkData = magicLinkData
        } catch {
            if #available(iOS 14, *) { Logger.connection.debug("Error while storing userData: \(error)") }
            // rollback the changes
            do {
                let rollbackMagicLinkData = self.magicLinkData
                try securedStorage.set(rollbackMagicLinkData?.magicLinkId, key: MagicLinkKeys.identifier)
                try securedStorage.set(rollbackMagicLinkData?.email, key: MagicLinkKeys.email)
            } catch {
                // if rollback did not work, retry the rollback with a delay
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let rollbackMagicLinkData = self.magicLinkData
                    try? securedStorage.set(rollbackMagicLinkData?.magicLinkId, key: MagicLinkKeys.identifier)
                    try? securedStorage.set(rollbackMagicLinkData?.email, key: MagicLinkKeys.email)
                }
            }
        }
    }
}
