//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Orders the writes of a member's gamification (level and total points) on their cached public profile by when the
/// request that read it started, not by when its response arrived.
///
/// Two responses write it: the member's public profile, and, for the connected member, their private profile. A public
/// profile requested before the member earned points can arrive after a private-profile refresh that already counts
/// them; written as it arrives, it would put the older total back, and the community data would keep it. So each
/// request takes a ticket right before it is sent, and a write only sets the gamification when its ticket is newer than
/// the ticket of the last gamification written for that profile. The other fields of the profile are always written.
///
/// `AuthenticatedCallProvider` sends a request again when the session changed during it. A replay reads the server as
/// it is then, so its ticket is the one taken right before it: requests go through `send(_:)`, from inside the closure
/// a replay calls again. The immediate retries the remote client makes when the server is unavailable keep the ticket
/// of the first attempt: a request sent between two attempts counts as newer than the retry, though it may have read an
/// older total than the retry did, and wins over it whatever order the two are written in. The cache can then keep
/// that older total until the next refresh, a window of one failed round trip.
///
/// Tickets are only compared within the process: no request outlives it, so the order starts empty at each launch.
final class ProfileGamificationOrder: @unchecked Sendable {
    /// When a request was sent, relative to the other requests of the process.
    struct Ticket: Comparable, Sendable {
        fileprivate let value: UInt64

        static func < (lhs: Ticket, rhs: Ticket) -> Bool { lhs.value < rhs.value }
    }

    private static let counterLock = NSLock()
    nonisolated(unsafe) private static var counter: UInt64 = 0

    /// A ticket newer than every ticket taken before it.
    static func nextTicket() -> Ticket {
        counterLock.lock()
        defer { counterLock.unlock() }
        counter += 1
        return Ticket(value: counter)
    }

    /// Sends a request that reads a member's gamification and returns its response with the ticket taken right before
    /// it was sent.
    static func send<Response>(_ request: () async throws -> Response) async throws -> (Response, Ticket) {
        let ticket = nextTicket()
        return (try await request(), ticket)
    }

    private let lock = NSLock()
    private var lastWrittenTickets = [String: Ticket]()

    /// Whether a response read with `ticket` may set the gamification of `profileId`. When it may, `ticket` becomes the
    /// one to beat for that profile.
    ///
    /// To call on the queue of the write, right before it: claims are then made in the order the writes happen.
    /// - Parameter force: claims even if a newer ticket was claimed, for a profile that is written anew (after the
    ///   cache was purged, say): its gamification is then the one of `ticket`, which must be the one to beat.
    func claim(_ ticket: Ticket, for profileId: String, force: Bool = false) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if !force, let lastWrittenTicket = lastWrittenTickets[profileId], lastWrittenTicket > ticket { return false }
        lastWrittenTickets[profileId] = ticket
        return true
    }
}
