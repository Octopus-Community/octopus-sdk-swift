//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import NIOHPACK
@testable import OctopusRemoteClient

/// An access taken away while the app runs (a ban, an exclusion) first shows as calls the server refuses, naming
/// the member's reason in the `octopus-reason` trailer: `callRemote` reports each of them, so that the core can read
/// the access again.
@Suite("Access refusal")
struct AccessRefusalTests {

    /// Mutable counter usable from the `Sendable` handler.
    private final class Counter: @unchecked Sendable {
        var value = 0
        /// What the last report said of the session.
        var endsSession: Bool?
    }

    private func refusal(_ reason: String = "account_banned") -> GRPCStatus {
        CommunityClosedRefusal.mark(GRPCStatus(code: .permissionDenied, message: "Denied"),
                                    trailers: ["octopus-reason": reason])
    }

    // MARK: Reading the trailer

    @Test(arguments: ["account_banned", "account_deleted", "member_excluded", "no_access_cohort"])
    func aPermissionDeniedNamingTheMemberReasonIsMarked(reason: String) {
        let marked = refusal(reason)

        #expect(marked.code == .permissionDenied)
        #expect(marked.message == "Denied")
        #expect((marked.cause as? AccessRefusal)?.endsSession == false)
    }

    /// The server ends the session of the guest a banned device was given once the account behind it is no longer
    /// banned.
    @Test func aPermissionDeniedNamingAnEndedSessionIsMarkedAsEndingIt() {
        #expect((refusal("session_ended").cause as? AccessRefusal)?.endsSession == true)
    }

    @Test(arguments: ["community_closed", "community_temporarily_disabled", "something_else"])
    func anotherReasonIsNotMarked(reason: String) {
        #expect(!(refusal(reason).cause is AccessRefusal))
    }

    @Test func anotherCodeIsNotMarked() {
        let marked = CommunityClosedRefusal.mark(GRPCStatus(code: .unauthenticated, message: nil),
                                                 trailers: ["octopus-reason": "account_banned"])

        #expect(marked.cause == nil)
    }

    // MARK: Reporting it

    private func makeClient(reports counter: Counter, callsGate: CallsGate = CallsGate()) -> ServiceClient {
        let client = ServiceClient(apiKey: "api-key", sdkVersion: "1.16.0", installId: "install-id",
                                   localeIdentifier: "fr_FR",
                                   sdkIdentity: { SdkIdentity(family: .native, version: "1.16.0") },
                                   callsGate: callsGate)
        client.set(accessRefusedHandler: {
            counter.value += 1
            counter.endsSession = $0
        })
        return client
    }

    private func call(_ client: ServiceClient, token: String? = nil, failingWith error: Error) async {
        let method: AuthenticationMethod = if let token {
            .authenticated(token: token, authFailure: { })
        } else {
            .notAuthenticated
        }
        do {
            let _: Int = try await client.callRemote(method) { throw error }
            Issue.record("callRemote should have rethrown the error")
        } catch {
            // expected
        }
    }

    @Test func aRefusalNamingTheMemberReasonIsReported() async {
        let counter = Counter()

        await call(makeClient(reports: counter), failingWith: refusal())

        #expect(counter.value == 1)
        #expect(counter.endsSession == false)
    }

    @Test func aRefusalNamingAnEndedSessionIsReportedAsEndingIt() async {
        let counter = Counter()

        await call(makeClient(reports: counter), failingWith: refusal("session_ended"))

        #expect(counter.value == 1)
        #expect(counter.endsSession == true)
    }

    /// A hidden group, or a right the user does not have, is refused with the same code and no reason: it says
    /// nothing about the access.
    @Test func aPermissionDeniedNamingNoReasonIsNotReported() async {
        let counter = Counter()

        await call(makeClient(reports: counter), failingWith: GRPCStatus(code: .permissionDenied, message: "Denied"))

        #expect(counter.value == 0)
    }

    /// A closed community is told by the config, not by the access.
    @Test func aRefusalNamingTheClosureIsNotReported() async {
        let counter = Counter()

        await call(makeClient(reports: counter), failingWith: refusal("community_closed"))

        #expect(counter.value == 0)
    }

    @Test(arguments: [GRPCStatus.Code.unauthenticated, .notFound, .unavailable, .internalError])
    func anotherFailureIsNotReported(code: GRPCStatus.Code) async {
        let counter = Counter()

        await call(makeClient(reports: counter), token: TestJwt.expiring(in: 3600),
                   failingWith: GRPCStatus(code: code, message: nil))

        #expect(counter.value == 0)
    }

    /// A blocked call was never sent: the server refused nothing.
    @Test func aBlockedCallIsNotReported() async {
        let counter = Counter()
        let gate = CallsGate()
        gate.isBlocked = true

        await call(makeClient(reports: counter, callsGate: gate), failingWith: refusal())

        #expect(counter.value == 0)
    }
}
