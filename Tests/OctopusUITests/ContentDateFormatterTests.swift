//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

struct ContentDateFormatterTests {
    private let calendar = Calendar.current
    private let now: Date

    init() {
        now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
    }

    private func formatter(_ localeIdentifier: String) -> ContentDateFormatter {
        let formatter = ContentDateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        return formatter
    }

    private func date(secondsAgo seconds: TimeInterval) -> Date {
        now.addingTimeInterval(-seconds)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test(arguments: [
        (0, "1m"),
        (20, "1m"),
        (8 * 60, "8m"),
        (59 * 60 + 59, "59m"),
        (3 * 3600, "3h"),
        (23 * 3600 + 59 * 60, "23h"),
        (24 * 3600, "1d"),
        (6 * 86400, "6d"),
        (7 * 86400, "1w"),
        (34 * 86400, "4w"),
    ] as [(TimeInterval, String)])
    func englishDurationsAreShort(secondsAgo: TimeInterval, expected: String) {
        let result = formatter("en_US").displayableDate(for: date(secondsAgo: secondsAgo), relativeTo: now)
        #expect(result.text == expected)
    }

    @Test(arguments: [
        (20, "1min"),
        (3 * 3600, "3h"),
        (86400, "1j"),
        (21 * 86400, "3sem"),
    ] as [(TimeInterval, String)])
    func frenchDurationsAreShort(secondsAgo: TimeInterval, expected: String) {
        let result = formatter("fr_FR").displayableDate(for: date(secondsAgo: secondsAgo), relativeTo: now)
        #expect(result.text == expected)
    }

    @Test func aDateInTheFutureReadsAsOneMinute() {
        let result = formatter("en_US").displayableDate(for: now.addingTimeInterval(120), relativeTo: now)
        #expect(result.text == "1m")
    }

    @Test func fiveWeeksOrMoreShowsTheDateWithoutTheCurrentYear() {
        let fiveWeeksAgo = formatter("en_US").displayableDate(for: date(secondsAgo: 35 * 86400), relativeTo: now)
        #expect(fiveWeeksAgo.text == "Sep 25")

        let french = formatter("fr_FR").displayableDate(for: date(year: 2026, month: 9, day: 12), relativeTo: now)
        #expect(french.text == "12 sept.")
    }

    @Test func aDateOfAnotherYearShowsTheYear() {
        let english = formatter("en_US").displayableDate(for: date(year: 2025, month: 10, day: 12), relativeTo: now)
        #expect(english.text == "Oct 12, 2025")

        let french = formatter("fr_FR").displayableDate(for: date(year: 2025, month: 10, day: 12), relativeTo: now)
        #expect(french.text == "12 oct. 2025")
    }

    @Test func aDateOfLastYearShowsTheYearEvenWhenRecent() {
        let newYear = date(year: 2026, month: 1, day: 20)
        let result = formatter("en_US").displayableDate(for: date(year: 2025, month: 12, day: 10), relativeTo: newYear)
        #expect(result.text == "Dec 10, 2025")
    }

    @Test func voiceOverReadsTheLongForm() {
        let english = formatter("en_US")
        #expect(english.displayableDate(for: date(secondsAgo: 20), relativeTo: now).accessibilityText
                == "1 minute ago")
        #expect(english.displayableDate(for: date(secondsAgo: 8 * 60), relativeTo: now).accessibilityText
                == "8 minutes ago")
        #expect(english.displayableDate(for: date(secondsAgo: 14 * 86400), relativeTo: now).accessibilityText
                == "2 weeks ago")
        // The cell summaries insert it in a sentence built around a relative phrase, so it stays relative once the
        // date is shown.
        #expect(english.displayableDate(for: date(year: 2026, month: 9, day: 12), relativeTo: now).accessibilityText
                == "1 month ago")
        #expect(english.displayableDate(for: date(year: 2025, month: 10, day: 12), relativeTo: now).accessibilityText
                == "1 year ago")

        let french = formatter("fr_FR")
        #expect(french.displayableDate(for: date(secondsAgo: 8 * 60), relativeTo: now).accessibilityText
                == "il y a 8 minutes")
        #expect(french.displayableDate(for: date(year: 2025, month: 10, day: 12), relativeTo: now).accessibilityText
                == "il y a 1 an")
    }

    @Test func changingTheLocaleReformats() {
        let formatter = formatter("en_US")
        formatter.locale = Locale(identifier: "fr_FR")
        #expect(formatter.displayableDate(for: date(secondsAgo: 86400), relativeTo: now).text == "1j")
    }
}
