//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit
import DependencyInjection

public extension Validators {
    class Picture {
        public enum ValidationResult {
            case valid
            case sideTooSmall
            case ratioTooBig
        }

        public let minSize: CGFloat = 50
        public let maxRatio: CGFloat = 32/9
        public let maxRatioStr = "32:9"
        public func validate(_ image: UIImage) -> ValidationResult {
            let width = image.size.width
            let height = image.size.height
            let minSize = min(width, height)
            let maxSize = max(width, height)
            guard minSize >= self.minSize else {
                return .sideTooSmall
            }
            guard maxSize / minSize <= maxRatio else {
                return .ratioTooBig
            }
            return .valid
        }
    }
}
