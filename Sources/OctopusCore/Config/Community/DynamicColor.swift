//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A color information for both light and dark mode
public struct DynamicColor: Equatable, Sendable {
    public let hexLight: String
    public let hexDark: String

    /// Public constructor, only for SwiftUI previews
    public init(hexLight: String, hexDark: String) {
        self.hexLight = hexLight
        self.hexDark = hexDark
    }
}
