//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public struct DarkLightValue<Value: Equatable & Sendable>: Equatable, Sendable {
    public let lightValue: Value
    public let darkValue: Value

    /// Public constructor, only for SwiftUI previews
    public init(lightValue: Value, darkValue: Value) {
        self.lightValue = lightValue
        self.darkValue = darkValue
    }
}

/// A color information for both light and dark mode
public typealias DynamicColor = DarkLightValue<String>
