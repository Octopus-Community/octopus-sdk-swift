//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// Extension of Bundle that adds the `.module` computed property when not compiled in a Swift Package
extension Bundle {
#if !SWIFT_PACKAGE
    static var module: Bundle = {
            let bundleName = "OctopusCore"

            let candidates = [
                Bundle(for: OctopusSDKCore.self),
                Bundle.main,
            ]

            for candidate in candidates {
                if let url = candidate.url(forResource: bundleName, withExtension: "bundle"),
                   let bundle = Bundle(url: url) {
                    return bundle
                }
            }

            fatalError("Cannot find resource bundle named \(bundleName)")
        }()
#endif
}
