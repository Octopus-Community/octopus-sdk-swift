//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

extension UIContentSizeCategory {
    /// A backwards compatible version of the iOS 14 `UIContentSizeCategory(_: ContentSizeCategory)`.
    ///
    /// Always the mapping below, on every OS, so that the tests comparing it to UIKit's cover it.
    init(compat sizeCategory: ContentSizeCategory) {
        switch sizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}
