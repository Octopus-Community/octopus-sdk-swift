//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

extension RelativeDateTimeFormatter {
    /// Formats the date interval from the reference date to the specified date using the formatter’s calendar.
    ///
    /// - Note: this simply calls `localizedString(for:relativeTo:)` but changes the dateTimeStyle according to the
    /// dates. This is because when two dates are the same, the formatter uses the future "In 0 sec." instead of the
    /// past "0 sec. ago". In that case, we use the `.named` style to have `now`. In all other cases, we set the
    /// `.numeric` style.
    func customLocalizedStructure(for date: Date, relativeTo referenceDate: Date) -> String {
        if abs(date.timeIntervalSince1970 - referenceDate.timeIntervalSince1970) <= 1 {
            self.dateTimeStyle = .named
        } else {
            self.dateTimeStyle = .numeric
        }
        return localizedString(for: date, relativeTo: referenceDate)
    }
}
