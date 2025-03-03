//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

@propertyWrapper
public struct UserDefault<T> {

    public var wrappedValue: T? {
        get { UserDefaults.standard.value(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    private let key: String
    public let defaultValue: T?

    public init(key: String, defaultValue: T? = nil) {
        self.key = key
        self.defaultValue = defaultValue
    }
}
