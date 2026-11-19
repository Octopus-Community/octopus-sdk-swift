//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// The config says whether the community is closed, and from when the SDK may check it again. A date already past
/// would make the SDK check at every launch: a floor applies then, longer for a closure than for a temporary
/// disabling.
struct CommunityClosureTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func noDisabledFieldMeansOpen() {
        #expect(CommunityClosure(from: Com_Octopuscommunity_ApiKeyConfig(), now: now) == nil)
    }

    @Test(arguments: [CommunityClosure.Kind.closed, .temporarilyDisabled])
    func aFutureNextCheckAtIsKept(kind: CommunityClosure.Kind) throws {
        let closure = try #require(CommunityClosure(
            from: config(kind: kind, message: "Closed msg", nextCheckAt: now.addingTimeInterval(300)), now: now))

        #expect(closure == CommunityClosure(kind: kind, message: "Closed msg",
                                            nextCheckDate: now.addingTimeInterval(300)))
    }

    @Test func aPastNextCheckAtOnAClosureWaitsADay() throws {
        let closure = try #require(CommunityClosure(
            from: config(kind: .closed, nextCheckAt: now.addingTimeInterval(-3_600)), now: now))

        #expect(closure.nextCheckDate == now.addingTimeInterval(86_400))
    }

    @Test func aPastNextCheckAtOnATemporaryDisablingWaitsAnHour() throws {
        let closure = try #require(CommunityClosure(
            from: config(kind: .temporarilyDisabled, nextCheckAt: now.addingTimeInterval(-3_600)), now: now))

        #expect(closure.nextCheckDate == now.addingTimeInterval(3_600))
    }

    @Test(arguments: [(CommunityClosure.Kind.closed, 86_400.0), (.temporarilyDisabled, 3_600.0)])
    func aZeroNextCheckAtFallsBackToTheFloor(kind: CommunityClosure.Kind, floor: TimeInterval) throws {
        let closure = try #require(CommunityClosure(from: config(kind: kind, nextCheckAt: nil), now: now))

        #expect(closure.nextCheckDate == now.addingTimeInterval(floor))
    }

    /// A config whose `disabled` field is set. A nil `nextCheckAt` leaves the field to its default, 0.
    private func config(kind: CommunityClosure.Kind, message: String = "", nextCheckAt: Date?)
    -> Com_Octopuscommunity_ApiKeyConfig {
        let millis = nextCheckAt.map { UInt64($0.timeIntervalSince1970 * 1000) } ?? 0
        var config = Com_Octopuscommunity_ApiKeyConfig()
        switch kind {
        case .closed:
            config.closed = .with {
                $0.message = message
                $0.nextCheckAt = millis
            }
        case .temporarilyDisabled:
            config.temporarilyDisabled = .with {
                $0.message = message
                $0.nextCheckAt = millis
            }
        }
        return config
    }
}
