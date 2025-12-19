//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

enum Seniority: Equatable {
    case days(Int)
    case weeks(Int)
    case months(Int)
    case years(Int)

    init(from date: Date, refDate: Date = Date()) {
        let calendar = Calendar.current

        let days = calendar.dateComponents([.day], from: date, to: refDate).day ?? 0
        let weeks = days / 7
        let months = calendar.dateComponents([.month], from: date, to: refDate).month ?? 0
        let years = calendar.dateComponents([.year], from: date, to: refDate).year ?? 0

        if days < 7 {
            self = .days(max(days, 1))
        } else if weeks < 4 {
            self = .weeks(max(weeks, 1))
        } else if months < 12 {
            self = .months(max(months, 1))
        } else {
            self = .years(max(years, 1))
        }
    }

    var localizedKey: LocalizedStringKey {
        switch self {
        case let .days(value): "Common.Duration.Day_value:\(value)"
        case let .weeks(value): "Common.Duration.Week_value:\(value)"
        case let .months(value): "Common.Duration.Month_value:\(value)"
        case let .years(value): "Common.Duration.Year_value:\(value)"
        }
    }
}
