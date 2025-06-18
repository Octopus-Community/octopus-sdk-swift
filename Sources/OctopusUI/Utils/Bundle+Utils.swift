//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// Empty class only used to create a bundle with `Bundle(for: BundleModuleLocator.self)`.
class BundleModuleLocator { }

/// Extension of Bundle that adds the `.module` computed property when not compiled in a Swift Package
extension Bundle {
#if !SWIFT_PACKAGE
    static var module: Bundle { Bundle(for: BundleModuleLocator.self) }
#endif
}
