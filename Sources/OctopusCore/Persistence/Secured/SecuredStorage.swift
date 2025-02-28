//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import KeychainAccess
import DependencyInjection

extension Injected {
    static let securedStorage = Injector.InjectedIdentifier<SecuredStorage>()
}

protocol SecuredStorage: AnyObject {
    subscript(_ key: String) -> String? { get set }
}

class SecuredStorageDefault: SecuredStorage, InjectableObject {
    static let injectedIdentifier = Injected.securedStorage

    private let keychain: Keychain
    @UserDefault(key: "OctopusSDK.InstallId") private var installId: String?

    init(apiKey: String) {
        keychain = Keychain(service: "com.octopus.keychain\(Bundle.main.bundleIdentifier.map { ".\($0)" } ?? "")")
        // delete the content of the keychain if the app has been re-installed
        if installId == nil {
            installId = UUID().uuidString
            try? keychain.removeAll()
        }

    }

    subscript(_ key: String) -> String? {
        get { keychain[key] }
        set { keychain[key] = newValue }
    }
}
