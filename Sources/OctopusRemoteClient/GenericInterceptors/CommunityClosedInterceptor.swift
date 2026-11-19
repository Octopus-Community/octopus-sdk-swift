//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import NIOHPACK

/// Marks the refusals whose reason the server names, which only its trailers tell: the generated async calls throw
/// the status alone. A closed or temporarily disabled community is marked with `CommunityClosedRefusal`, a user who
/// has no access themself with `AccessRefusal`.
class CommunityClosedInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {
    override func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
        if case let .end(status, trailers) = part {
            context.receive(.end(CommunityClosedRefusal.mark(status, trailers: trailers), trailers))
        } else {
            context.receive(part)
        }
    }
}

/// The cause of a `permissionDenied` status the server sent because the community is closed or temporarily disabled.
///
/// The server refuses with the same code for other reasons (a hidden group, an excluded user, a failing A/B score),
/// and its description is a translated text for the user: it names the reason in the `octopus-reason` trailer.
struct CommunityClosedRefusal: Error {
    private static let reasons: Set<String> = ["community_closed", "community_temporarily_disabled"]

    static func mark(_ status: GRPCStatus, trailers: HPACKHeaders) -> GRPCStatus {
        guard status.code == .permissionDenied, let reason = trailers.first(name: "octopus-reason") else {
            return status
        }
        if reasons.contains(reason) {
            return GRPCStatus(code: status.code, message: status.message, cause: CommunityClosedRefusal())
        }
        if AccessRefusal.reasons.contains(reason) {
            return GRPCStatus(code: status.code, message: status.message,
                              cause: AccessRefusal(endsSession: reason == AccessRefusal.sessionEndedReason))
        }
        return status
    }
}

/// The cause of a `permissionDenied` status the server sent because the user themself has no access to the
/// community: banned, deleted, excluded, or out of the audience it is opened to. Or because their session is over.
///
/// The server names it in the same `octopus-reason` trailer, with the cases of the access it gives when asked.
/// A hidden group, or a right the user does not have, is refused with the same code and no reason.
struct AccessRefusal: Error {
    /// The session is over and must be replaced: the one of the guest a banned device was given, once the account
    /// behind it is no longer banned.
    fileprivate static let sessionEndedReason = "session_ended"
    fileprivate static let reasons: Set<String> = [
        "account_banned", "account_deleted", "member_excluded", "no_access_cohort", sessionEndedReason]

    /// Whether the server refused the call because the session is over, which the stored access, read before, does
    /// not know yet.
    let endsSession: Bool
}
