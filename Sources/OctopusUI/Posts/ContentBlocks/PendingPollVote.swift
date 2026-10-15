//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The option a poll shows as picked while its vote is in flight, so the tap is answered at once.
///
/// Every attempt settles: a vote that was not cast (no network, refused, failed) gives the options back so
/// the member can vote again, instead of leaving the poll stuck on a pick nobody recorded. A cast vote
/// keeps the pick until the post itself carries the vote (`confirmed()`), so the results never flash back
/// to the buttons in between.
struct PendingPollVote: Equatable {
    private(set) var optionId: String?

    mutating func start(optionId: String) {
        self.optionId = optionId
    }

    /// The vote request is over; `voted` tells whether the vote was cast.
    mutating func settle(voted: Bool) {
        guard !voted else { return }
        optionId = nil
    }

    /// The post now carries the member's vote, which takes over from the pending pick.
    mutating func confirmed() {
        optionId = nil
    }
}
