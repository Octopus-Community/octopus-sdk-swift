//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

extension Date {
    /// Unix timestamp from a date. Everything before unix epoch is considered to be unix epoch
    var timestampMs: UInt64 {
        let timestamp = self.timeIntervalSince1970 * 1000
        if timestamp >= 0 && timestamp <= Double(UInt64.max) {
            return UInt64(timestamp)
        } else {
            return 0
        }
    }

    /// Build a date from unix timestamp in ms
    ///
    /// - Parameter timestampMs: Unix timestamp in ms
    init(timestampMs: UInt64) {
        self.init(timeIntervalSince1970: Double(timestampMs) / 1000)
    }
}

extension TimeInterval {
    static func seconds(_ value: Int) -> Self {
        return Double(value)
    }

    static func minutes(_ value: Int) -> Self {
        return seconds(60 * value)
    }

    static func hours(_ value: Int) -> Self {
        return minutes(60 * value)
    }

    static func days(_ value: Int) -> Self {
        return hours(24 * value)
    }

    static func months(_ value: Int) -> Self {
        return days(31 * value)
    }

    static func years(_ value: Int) -> Self {
        return months(12 * value)
    }
}

extension UInt64 {
    static func since(_ timeIntervals: TimeInterval...) -> Self {
        let timeInterval = timeIntervals.reduce(0, +)
        let date = Date().addingTimeInterval(-timeInterval)
        return date.timestampMs
    }
}
