//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI
@testable import OctopusCore // to import timeinterval extensions

@Suite
class SeniorityTests {
    @Test func testInitFromDate() async throws {
        // ref date is set to 2026-03-25 09:13:00 +0000 to avoid hour in less than 28 days before
        // because that would break the Seniority computation
        // (for example Seniority(from: refDate.since(.days(28))) would have been 3 week and not 1 month)
        let refDate = Date(timeIntervalSinceReferenceDate: 796122780)

        #expect(Seniority(from: refDate.since(.hours(12)), refDate: refDate) == .days(1))
        #expect(Seniority(from: refDate.since(.days(1), .hours(12)), refDate: refDate) == .days(1))
        #expect(Seniority(from: refDate.since(.days(1), .hours(23), .minutes(59), .seconds(59)), refDate: refDate) == .days(1))
        #expect(Seniority(from: refDate.since(.days(1), .hours(24), .minutes(59), .seconds(59)), refDate: refDate) == .days(2))
        #expect(Seniority(from: refDate.since(.days(6), .hours(23), .minutes(59), .seconds(59)), refDate: refDate) == .days(6))
        #expect(Seniority(from: refDate.since(.days(7)), refDate: refDate) == .weeks(1))
        #expect(Seniority(from: refDate.since(.days(8)), refDate: refDate) == .weeks(1))
        #expect(Seniority(from: refDate.since(.days(13), .hours(23), .minutes(59), .seconds(59)), refDate: refDate) == .weeks(1))
        #expect(Seniority(from: refDate.since(.days(14)), refDate: refDate) == .weeks(2))
        #expect(Seniority(from: refDate.since(.days(20), .hours(23), .minutes(59), .seconds(59)), refDate: refDate) == .weeks(2))
        #expect(Seniority(from: refDate.since(.days(21)), refDate: refDate) == .weeks(3))
        #expect(Seniority(from: refDate.since(.days(27), .hours(23), .minutes(59), .seconds(59)), refDate: refDate) == .weeks(3))
        #expect(Seniority(from: refDate.since(.days(28)), refDate: refDate) == .months(1))
        #expect(Seniority(from: refDate.since(.days(364), .hours(23), .minutes(59), .seconds(59)), refDate: refDate) == .months(11))
        #expect(Seniority(from: refDate.since(.days(365)), refDate: refDate) == .years(1))
        #expect(Seniority(from: refDate.since(.days(365*2)), refDate: refDate) == .years(2))
    }
}

private extension Date {
    func since(_ timeIntervals: TimeInterval...) -> Self {
        let timeInterval = timeIntervals.reduce(0, +)
        let date = addingTimeInterval(-timeInterval)
        return date
    }
}
