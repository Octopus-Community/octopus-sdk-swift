//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import DependencyInjection

class MockSecuredStorage: SecuredStorage, InjectableObject {
    static let injectedIdentifier = Injected.securedStorage

    private var storage: [String: String] = [:]
    init() { }

    subscript(key: String) -> String? {
        get { storage[key] }
        set { storage[key] = newValue }
    }
}
