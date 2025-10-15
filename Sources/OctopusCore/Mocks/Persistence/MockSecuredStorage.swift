//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection

class MockSecuredStorage: SecuredStorage, InjectableObject {
    static let injectedIdentifier = Injected.securedStorage

    private var storage: [String: String] = [:]
    init() { }

    func set(_ value: String?, key: String) throws {
        storage[key] = value
    }

    subscript(key: String) -> String? {
        get { storage[key] }
        set { storage[key] = newValue }
    }
}
