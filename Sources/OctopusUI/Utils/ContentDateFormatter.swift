//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The age of a post, a comment or a reply as their header displays it.
struct DisplayableDate: Equatable {
    /// The short form shown on screen, like "8m" or "Oct 12".
    let text: String
    /// The long form VoiceOver reads, like "8 minutes ago" or "October 12".
    let accessibilityText: String
}

extension DisplayableDate: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(text: value, accessibilityText: value)
    }
}

/// Formats the age of a post, a comment or a reply in the short form social apps use: "8m", "3h", "2d", "3w", then
/// the date once it is 5 weeks old or more. Every form comes from the system formatters, so all languages follow
/// without any wording of ours.
///
/// VoiceOver always gets a relative phrase ("8 minutes ago", "2 months ago"), even when the date is shown: the cell
/// summaries insert it in sentences written around a relative phrase.
///
/// The SDK's locale can be overridden from any thread while view models format dates, hence the lock.
class ContentDateFormatter {
    var locale: Locale {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _locale
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _locale = newValue
            updateLocale()
        }
    }

    private let lock = NSLock()
    private var _locale: Locale = .current
    private var calendar = Calendar.current
    private let durationFormatter = DateComponentsFormatter()
    private let accessibleDurationFormatter = RelativeDateTimeFormatter()
    private let dateFormatter = DateFormatter()
    private let dateWithYearFormatter = DateFormatter()

    init() {
        durationFormatter.unitsStyle = .abbreviated
        durationFormatter.maximumUnitCount = 1
        accessibleDurationFormatter.unitsStyle = .full
        accessibleDurationFormatter.dateTimeStyle = .numeric
        updateLocale()
    }

    func displayableDate(for date: Date, relativeTo referenceDate: Date = Date()) -> DisplayableDate {
        lock.lock()
        defer { lock.unlock() }

        // A date slightly in the future (clock skew with the server) reads as the youngest age we display.
        let seconds = max(Int(referenceDate.timeIntervalSince(date)), 0)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        let components: DateComponents
        if hours < 1 {
            components = DateComponents(minute: max(minutes, 1))
        } else if days < 1 {
            components = DateComponents(hour: hours)
        } else if days < 7 {
            components = DateComponents(day: days)
        } else if days < 35 {
            components = DateComponents(weekOfMonth: days / 7)
        } else {
            let sameYear = calendar.isDate(date, equalTo: referenceDate, toGranularity: .year)
            return DisplayableDate(
                text: (sameYear ? dateFormatter : dateWithYearFormatter).string(from: date),
                accessibilityText: accessibleDurationFormatter.localizedString(for: date, relativeTo: referenceDate))
        }

        var pastComponents = DateComponents()
        pastComponents.minute = components.minute.map { -$0 }
        pastComponents.hour = components.hour.map { -$0 }
        pastComponents.day = components.day.map { -$0 }
        pastComponents.weekOfMonth = components.weekOfMonth.map { -$0 }
        return DisplayableDate(
            text: durationFormatter.string(from: components) ?? "",
            accessibilityText: accessibleDurationFormatter.localizedString(from: pastComponents))
    }

    /// Must be called with the lock held.
    private func updateLocale() {
        calendar.locale = _locale
        durationFormatter.calendar = calendar
        accessibleDurationFormatter.locale = _locale
        accessibleDurationFormatter.calendar = calendar
        for (formatter, template) in [(dateFormatter, "dMMM"), (dateWithYearFormatter, "dMMMy")] {
            formatter.locale = _locale
            formatter.calendar = calendar
            formatter.setLocalizedDateFormatFromTemplate(template)
        }
    }
}
