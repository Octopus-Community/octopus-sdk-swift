//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Compat {
    /// A metric that scales according to the Dynamic size category
    /// Same behavior as ScaledMetric but compatible with iOS 13.
    @propertyWrapper
    struct ScaledMetric<Value: BinaryFloatingPoint>: DynamicProperty {
        @Environment(\.sizeCategory) var sizeCategory // Accessing this triggers view updates

        var wrappedValue: Value {
            // Use UIFontMetrics to scale the value based on the current text size settings
            let scaledValue = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: CGFloat(baseValue))
            return Value(scaledValue)
        }

        let baseValue: Value
        let textStyle: UIFont.TextStyle

        init(wrappedValue: Value, relativeTo textStyle: UIFont.TextStyle = .body) {
            self.baseValue = wrappedValue
            self.textStyle = textStyle
        }
    }

}
