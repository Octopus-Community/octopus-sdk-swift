//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// Extension of Bundle that adds the `.module` computed property when not compiled in a Swift Package
extension Bundle {
#if !SWIFT_PACKAGE
    static var module: Bundle { Bundle(for: OctopusSDKCore.self) }
#endif
}
