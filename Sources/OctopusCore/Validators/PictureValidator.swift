//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit

public extension Validators {
    enum Picture {
        public enum ValidationResult {
            case valid
            case sideTooSmall
            case ratioTooBig
        }

        public static let minSize: CGFloat = 50
        public static let maxRatio: CGFloat = 32/9
        public static let maxRatioStr = "32:9"

        public static func validate(_ image: UIImage) -> ValidationResult {
            let width = image.size.width
            let height = image.size.height
            let minSize = min(width, height)
            let maxSize = max(width, height)
            guard minSize >= Self.minSize else {
                return .sideTooSmall
            }
            guard maxSize / minSize <= maxRatio else {
                return .ratioTooBig
            }
            return .valid
        }
    }
}
