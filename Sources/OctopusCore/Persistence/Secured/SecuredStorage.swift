//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import KeychainAccess
import OctopusDependencyInjection

extension Injected {
    static let securedStorage = Injector.InjectedIdentifier<SecuredStorage>()
}

/// Errors of the Keychain-backed stores that callers handle on their own.
enum SecuredStorageError: Error {
    /// The Keychain cannot be read yet: the device has not been unlocked since it started. Temporary, unlike the
    /// other read errors (an undecodable value, a missing entitlement…), which no wait would cure.
    case unavailableUntilFirstUnlock

    /// The error to report for one thrown by KeychainAccess: `unavailableUntilFirstUnlock` when it stands for that.
    static func from(keychainError error: Error) -> Error {
        guard case KeychainAccess.Status.interactionNotAllowed = error else { return error }
        return SecuredStorageError.unavailableUntilFirstUnlock
    }
}

protocol SecuredStorage: AnyObject {
    /// The stored value, `nil` when the store could not be read as well as when there is none: only fit for a
    /// value whose absence does no harm.
    subscript(_ key: String) -> String? { get set }
    /// The stored value, or `nil` when there is none.
    /// - Throws: `SecuredStorageError.unavailableUntilFirstUnlock` before the device's first unlock after a
    ///   reboot, or the error that made the value unreadable.
    func value(forKey key: String) throws -> String?
    func set(_ value: String?, key: String) throws
}

class SecuredStorageDefault: SecuredStorage, InjectableObject {
    static let injectedIdentifier = Injected.securedStorage

    private let keychain: Keychain

    init(apiKey: String, isNewInstall: Bool) {
        keychain = Keychain(service: "com.octopus.keychain\(Bundle.main.bundleIdentifier.map { ".\($0)" } ?? "")")
        // delete the content of the keychain if the app has been re-installed
        //
        // Only the session lives here (user id, token), so a reinstall still starts
        // logged out, exactly as before. The install id is deliberately NOT in this service: it
        // has to outlive a reinstall for a device ban to hold, so it sits in its own Keychain service that
        // this never touches — see `KeychainInstallIdStorage`.
        if isNewInstall {
            try? keychain.removeAll()
        }
    }

    func value(forKey key: String) throws -> String? {
        do {
            return try keychain.get(key)
        } catch {
            throw SecuredStorageError.from(keychainError: error)
        }
    }

    func set(_ value: String?, key: String) throws {
        if let value {
            try keychain.set(value, key: key)
        } else {
            try keychain.remove(key)
        }
    }

    subscript(_ key: String) -> String? {
        get { keychain[key] }
        set { keychain[key] = newValue }
    }
}
