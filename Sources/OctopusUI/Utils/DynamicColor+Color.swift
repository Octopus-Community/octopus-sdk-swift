//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

extension DynamicColor {
    var color: Color {
        Color(UIColor { traitCollection in
            let hex = (traitCollection.userInterfaceStyle == .dark) ? hexDark : hexLight
            return UIColor(hex: hex) ?? .clear
        })
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        switch length {
        case 6:
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        case 8:
            let a = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            let r = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }
}
