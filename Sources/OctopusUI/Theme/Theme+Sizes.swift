//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import CoreGraphics

extension OctopusTheme {
    /// Internal spacing tokens used across OctopusUI views. Not part of the public theming API.
    struct Sizes: Sendable {
        /// Default horizontal content padding used across screens and cards.
        let horizontalPadding: CGFloat = 16
    }

    /// Internal spacing tokens. See `OctopusTheme.Sizes`.
    var sizes: Sizes { Sizes() }
}
