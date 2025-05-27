//
//  Copyright © 2025 Octopus Community. All rights reserved.
//


import Foundation
import SwiftUI
import UIKit

extension Compat {
    enum VerticalEdge {
        /// The top edge.
        case top
        /// The bottom edge.
        case bottom

        @available(iOS 15.0, *)
        var usableValue: SwiftUI.VerticalEdge {
            switch self {
            case .top: .top
            case .bottom: .bottom
            }
        }

        struct Set: OptionSet {

            let rawValue: Int8
            static let top = VerticalEdge.Set(rawValue: 1 << 0)
            static let bottom  = VerticalEdge.Set(rawValue: 1 << 1)
            static let all: VerticalEdge.Set = [.top, .bottom]

            @available(iOS 15.0, *)
            var usableValue: SwiftUI.VerticalEdge.Set {
                var value = SwiftUI.VerticalEdge.Set()
                if contains(.top) { value.insert(.top) }
                if contains(.bottom) { value.insert(.bottom) }
                return value
            }
        }
    }
}
