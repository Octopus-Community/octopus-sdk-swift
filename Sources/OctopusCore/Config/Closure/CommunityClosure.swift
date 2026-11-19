//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The community is closed by Octopus: the SDK makes no call to the server until `nextCheckDate`, when it checks the
/// config again.
struct CommunityClosure: Equatable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// Closed for good, as far as the SDK knows.
        case closed
        /// Disabled for a while.
        case temporarilyDisabled
    }

    let kind: Kind
    /// The text to display to the member, under the SDK's own title.
    let message: String
    /// The date before which the SDK does not check the community again.
    let nextCheckDate: Date

    init(kind: Kind, message: String, nextCheckDate: Date) {
        self.kind = kind
        self.message = message
        self.nextCheckDate = nextCheckDate
    }

    /// The closure the config describes, `nil` when the community is open.
    ///
    /// The date the server gives is kept when it is still to come, however close. A date already past (or no date)
    /// would make the SDK check again at every launch, so it waits a floor instead: a day for a closure, an hour for a
    /// temporary disabling, which is expected to end sooner.
    init?(from config: Com_Octopuscommunity_ApiKeyConfig, now: Date) {
        let kind: Kind
        let message: String
        let nextCheckAt: UInt64
        switch config.disabled {
        case let .closed(closed)?:
            (kind, message, nextCheckAt) = (.closed, closed.message, closed.nextCheckAt)
        case let .temporarilyDisabled(disabled)?:
            (kind, message, nextCheckAt) = (.temporarilyDisabled, disabled.message, disabled.nextCheckAt)
        case nil:
            return nil
        }
        let serverDate = Date(timeIntervalSince1970: TimeInterval(nextCheckAt) / 1000)
        let floor: TimeInterval = switch kind {
        case .closed: .days(1)
        case .temporarilyDisabled: .hours(1)
        }
        self.init(kind: kind, message: message,
                  nextCheckDate: serverDate > now ? serverDate : now.addingTimeInterval(floor))
    }
}
