//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

extension Compat {
    enum Visibility {
        case automatic
        case visible
        case hidden

        @available(iOS 15.0, *)
        var usableValue: SwiftUI.Visibility {
            switch self {
            case .automatic: return .automatic
            case .visible: return .visible
            case .hidden: return .hidden
            }
        }
    }

    enum VerticalEdge {
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

extension View {
    func listRowSeparator(
        _ visibility: Compat.Visibility, edges: Compat.VerticalEdge.Set = .all) -> some View {
        if #available(iOS 15.0, *) {
            return self.listRowSeparator(visibility.usableValue, edges: edges.usableValue)
        } else {
#if canImport(UIKit)
            // To remove only extra separators below the list:
            UITableView.appearance().tableFooterView = UIView()
            // To remove all separators including the actual ones:
            UITableView.appearance().separatorStyle = .none
#endif
            return self
        }
    }
}
