//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = OctopusTheme()
}

public extension EnvironmentValues {
    var octopusTheme: OctopusTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
