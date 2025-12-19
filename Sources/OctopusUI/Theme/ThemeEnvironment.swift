//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

private struct ThemeEnvironmentKey: EnvironmentKey {
    /// Computed property in order to be recomputed when dynamic size changes
    ///
    /// - Note: the environment should be set in order to avoid re-creating the default env each time a view accesses
    /// the default value
    static var defaultValue: OctopusTheme { OctopusTheme() }
}

public extension EnvironmentValues {
    var octopusTheme: OctopusTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
