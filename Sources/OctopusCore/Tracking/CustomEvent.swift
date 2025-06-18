//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// An event that has a meaning for the caller but quite opaque for the SDK.
public struct CustomEvent: Sendable {
    /// A value of a given property of a custom event
    public struct PropertyValue: Sendable {
        /// The value, passed as String
        public let value: String

        public init(value: String) {
            self.value = value
        }
    }
    /// Name of the event
    public let name: String
    /// The properties of this event, indexed by their property name
    public let properties: [String: PropertyValue]

    public init(name: String, properties: [String: PropertyValue] = [:]) {
        self.name = name
        self.properties = properties
    }
}
