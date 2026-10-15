//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import KeychainAccess
import OctopusDependencyInjection
import os
import UIKit

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

    /// Keys of the pending magic link request the SDK used to keep while users could sign in with an email
    /// link. Nothing reads them anymore; they are only listed to be wiped from the Keychain of apps that
    /// integrated that login before, since the stored email is personal data.
    private enum LegacyMagicLinkKeys {
        static let base = "magicLink"
        static let identifier = "\(base)_id"
        static let email = "\(base)_email"
    }

    @Published private(set) var userData: UserData?
    @Published private(set) var clientUserData: ClientUserData?
    /// `true` while the stored session could not be read, typically because the app was launched in the
    /// background before the device's first unlock after a reboot. `userData` and `clientUserData` are then
    /// `nil` without meaning that nobody is connected: nothing should log out, clean or connect a guest on
    /// their account. The session is read again once the device is unlocked.
    @Published private(set) var sessionIsUnreadable = false

    private let securedStorage: SecuredStorage
    /// Makes a read of the session and the stores atomic with one another: a read done on unlock must neither
    /// publish a session older than one stored meanwhile, nor let a store slip in while it decides. Recursive,
    /// since a subscriber to the published values may store in turn.
    ///
    /// The values are published while it is held, so a subscriber must never block on another thread (no
    /// `DispatchQueue.main.sync`, no `performAndWait` on a main queue context): hop with `receive(on:)` or a
    /// `Task` instead, as every subscriber does.
    private let lock = NSRecursiveLock()
    /// Watches the moments to read an unreadable session again; set and dropped under `lock`, since the session
    /// can become readable on any thread.
    private var sessionReadSubscription: AnyCancellable?

    /// The moments at which an unreadable session is worth reading again: the device being unlocked, and the
    /// app coming back, which covers that notification being missed while the app was suspended.
    static var defaultSessionReadTriggers: AnyPublisher<Void, Never> {
        Publishers.MergeMany(
            [UIApplication.protectedDataDidBecomeAvailableNotification,
             UIApplication.willEnterForegroundNotification,
             UIApplication.didBecomeActiveNotification]
                .map { NotificationCenter.default.publisher(for: $0).map { _ in }.eraseToAnyPublisher() }
        ).eraseToAnyPublisher()
    }

    /// - Parameter sessionReadTriggers: when to read an unreadable session again. Replaced by the tests, which
    ///   must not post system notifications to every storage alive in the process.
    init(injector: Injector,
         sessionReadTriggers: AnyPublisher<Void, Never> = UserDataStorage.defaultSessionReadTriggers) {
        securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage)
        // See `PublishedPublishers`: done before anything can write these values.
        PublishedPublishers.create($userData, $clientUserData, $sessionIsUnreadable)

        readSession()

        // Only needed until the session is read: `readSession` drops this subscription once it is.
        guard sessionIsUnreadable else { return }
        // Subscribed outside the lock, since a trigger may fire right away on another thread and take it, then kept
        // only if the session is still unreadable by then.
        let subscription = sessionReadTriggers.sink { [weak self] in self?.readSessionIfUnreadable() }
        lock.lock()
        defer { lock.unlock() }
        if sessionIsUnreadable { sessionReadSubscription = subscription }
    }

    /// Reads the session again if it could not be read so far.
    /// - Returns: whether the session is readable now.
    @discardableResult
    func readSessionIfUnreadable() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if sessionIsUnreadable { readSession() }
        return !sessionIsUnreadable
    }

    private func readSession() {
        lock.lock()
        defer { lock.unlock() }
        var userData: UserData?
        var clientUserData: ClientUserData?
        do {
            if let id = try securedStorage.value(forKey: UserKeys.id),
               let token = try securedStorage.value(forKey: UserKeys.jwtToken) {
                let clientId = try securedStorage.value(forKey: UserKeys.clientId)
                userData = UserData(id: id, clientId: clientId, jwtToken: token)
            }
            clientUserData = try securedStorage.value(forKey: ClientUserKeys.id).map { ClientUserData(id: $0) }
        } catch SecuredStorageError.unavailableUntilFirstUnlock {
            if #available(iOS 14, *) {
                Logger.connection.debug("The stored session cannot be read until the device is unlocked")
            }
            sessionIsUnreadable = true
            return
        } catch {
            // Not a matter of waiting for the unlock: no wait would make it readable. A session that cannot be read
            // counts as absent, so that a new one replaces it; all of it, even the values that could be read, so
            // that no half session is kept.
            if #available(iOS 14, *) { Logger.connection.error("The stored session is unreadable: \(error)") }
            userData = nil
            clientUserData = nil
        }

        // Published before the flag goes down, so that whoever waits for a readable session sees it right away.
        self.userData = userData
        self.clientUserData = clientUserData
        if sessionIsUnreadable {
            if #available(iOS 14, *) { Logger.connection.debug("The stored session could be read again") }
            sessionIsUnreadable = false
            // the session never becomes unreadable again: nothing left to read it again for
            sessionReadSubscription = nil
        }

        for key in [LegacyMagicLinkKeys.identifier, LegacyMagicLinkKeys.email] where securedStorage[key] != nil {
            try? securedStorage.set(nil, key: key)
        }
    }

    /// Whether a store must be refused: while the session cannot be read, writing could replace a session that
    /// was not read yet. Nothing is written or changed then; the session read on unlock decides.
    private func refusesStoreWhileUnreadable() -> Bool {
        guard sessionIsUnreadable else { return false }
        if #available(iOS 14, *) { Logger.connection.debug("Not storing the session: the stored one cannot be read") }
        return true
    }

    func store(userData: UserData?) {
        lock.lock()
        defer { lock.unlock() }
        guard !refusesStoreWhileUnreadable() else { return }
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
                    lock.lock()
                    defer { lock.unlock() }
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
        lock.lock()
        defer { lock.unlock() }
        guard !refusesStoreWhileUnreadable() else { return }
        do {
            try securedStorage.set(clientUserData?.id, key: ClientUserKeys.id)

            self.clientUserData = clientUserData
        } catch {
            if #available(iOS 14, *) { Logger.connection.debug("Error while storing client user data: \(error)") }
        }
    }
}
