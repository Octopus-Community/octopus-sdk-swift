//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import KeychainAccess
import OctopusDependencyInjection

extension Injected {
    static let securedStorage = Injector.InjectedIdentifier<SecuredStorage>()
}

protocol SecuredStorage: AnyObject {
    subscript(_ key: String) -> String? { get set }
    func set(_ value: String?, key: String) throws
}

class SecuredStorageDefault: SecuredStorage, InjectableObject {
    static let injectedIdentifier = Injected.securedStorage

    private let keychain: Keychain

    init(apiKey: String, isNewInstall: Bool) {
        keychain = Keychain(service: "com.octopus.keychain\(Bundle.main.bundleIdentifier.map { ".\($0)" } ?? "")")
        // delete the content of the keychain if the app has been re-installed
        if isNewInstall {
            try? keychain.removeAll()
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
