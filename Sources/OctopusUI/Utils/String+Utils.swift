//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

private extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.filter{ $0.isASCII }.first?.value
    }
}

private extension String {
    var asciiArray: [UInt32] {
        return unicodeScalars.filter{ $0.isASCII }.map { $0.value }
    }

    /// Produces the same hash code as in Kotlin
    func hashCode() -> Int32 {
        var h : Int32 = 0
        for i in self.asciiArray {
            h = 31 &* h &+ Int32(i)
        }
        return h
    }
}

extension String {
    var avatarColor: Color {
        let hash = hashCode()
        let red = CGFloat(abs(Int(hash) & 0xFF) % 128 + 128) / 255.0 // 128-255
        let green = CGFloat(abs((Int(hash) >> 8) & 0xFF) % 128 + 128) / 255.0 // 128-255
        let blue = CGFloat(abs((Int(hash) >> 16) & 0xFF) % 128 + 128) / 255.0 // 128-255

        return Color(red: red, green: green, blue: blue)
    }

    var initials: String {
        first?.uppercased() ?? ""
    }
}

extension String {
    private static let emailRegex = "^[A-Za-z][A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]+$"
    nonisolated(unsafe) private static let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)

    /// Returns `true` if Self matches a valid email format.
    var isValidEmail: Bool {
        String.emailPredicate.evaluate(with: self)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension String {
    var cleanedBio: String {
        return self
        // break into lines
            .components(separatedBy: .newlines)
        // remove trailing whitespaces
            .map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        // put back the new line
            .joined(separator: "\n")
        // replace 2 or more consecutive newlines with a single newline
            .replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
    }
}

extension String {
    static func formattedCount(_ count: Int) -> String {
        let num = Double(count)

        func format(_ value: Double, suffix: String) -> String {
            if value < 10 {
                let roundedToOne = (value * 10).rounded(.down) / 10
                // If rounded value is whole, print as integer (no .0)
                if roundedToOne.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(Int(roundedToOne))\(suffix)"
                } else {
                    return String(format: "%.1f", roundedToOne) + suffix
                }
            } else {
                return "\(Int(floor(value)))\(suffix)"
            }
        }

        switch num {
        case 0..<1000:
            return "\(count)"

        case 1000..<1_000_000:
            return format(num / 1000, suffix: "K")

        case 1_000_000..<1_000_000_000:
            return format(num / 1_000_000, suffix: "M")

        default:
            return format(num / 1_000_000_000, suffix: "B")
        }
    }

    static func formattedDuration(_ seconds: TimeInterval, displayHours: Bool) -> String {
        if #available(iOS 16, *) {
            let duration = Duration.seconds(seconds)
            return duration.formatted(
                .time(
                    pattern: displayHours ? .hourMinuteSecond(padHourToLength: 2) : .minuteSecond(padMinuteToLength: 2)
                )
            )
        } else {
            // Round to nearest whole second first (handles 59.999 → 60)
            let totalSeconds = Int(round(seconds))

            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let secs = totalSeconds % 60

            if displayHours {
                // HH:MM:SS
                return String(
                    format: "%02d:%02d:%02d",
                    hours, minutes, secs
                )
            } else {
                // MM:SS
                return String(
                    format: "%02d:%02d",
                    minutes + (hours * 60), secs
                )
            }
        }
    }
}
