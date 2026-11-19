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
import OctopusGrpcModels
@testable import OctopusRemoteClient

/// A community closed or temporarily disabled while the app runs first shows as calls the server refuses, naming
/// the reason in the `octopus-reason` trailer: `callRemote` reports each of them, so that the core can check the
/// config.
@Suite("Community closed refusal")
struct CommunityClosedRefusalTests {

    /// Mutable counter usable from the `Sendable` handler.
    private final class Counter: @unchecked Sendable {
        var value = 0
    }

    private let closedTrailers: HPACKHeaders = ["octopus-reason": "community_closed"]

    private func makeClient(reports counter: Counter) -> ServiceClient {
        let client = ServiceClient(apiKey: "api-key", sdkVersion: "1.16.0", installId: "install-id",
                                   localeIdentifier: "fr_FR",
                                   sdkIdentity: { SdkIdentity(family: .native, version: "1.16.0") })
        client.set(communityClosedHandler: { counter.value += 1 })
        return client
    }

    private func call(_ client: ServiceClient, failingWith error: Error) async {
        do {
            let _: Int = try await client.callRemote(.notAuthenticated) { throw error }
            Issue.record("callRemote should have rethrown the error")
        } catch {
            // expected
        }
    }

    // MARK: Reading the trailer

    /// A temporarily disabled community is named in the same trailer, with its own reason.
    @Test(arguments: ["community_closed", "community_temporarily_disabled"])
    func aPermissionDeniedNamingTheClosureIsMarked(reason: String) {
        let status = GRPCStatus(code: .permissionDenied, message: "Closed")

        let marked = CommunityClosedRefusal.mark(status, trailers: ["octopus-reason": reason])

        #expect(marked.code == .permissionDenied)
        #expect(marked.message == "Closed")
        #expect(marked.cause is CommunityClosedRefusal)
    }

    /// A hidden group, an exclusion or a failing A/B score is refused with the same code, and no reason.
    @Test func aPermissionDeniedNamingNoReasonIsNotMarked() {
        let marked = CommunityClosedRefusal.mark(GRPCStatus(code: .permissionDenied, message: "Denied"), trailers: [:])

        #expect(marked.cause == nil)
    }

    @Test func anotherReasonIsNotMarked() {
        let marked = CommunityClosedRefusal.mark(GRPCStatus(code: .permissionDenied, message: nil),
                                                 trailers: ["octopus-reason": "something_else"])

        #expect(marked.cause == nil)
    }

    @Test func anotherCodeIsNotMarked() {
        let marked = CommunityClosedRefusal.mark(GRPCStatus(code: .unauthenticated, message: nil),
                                                 trailers: closedTrailers)

        #expect(marked.cause == nil)
    }

    // MARK: Which calls read it

    /// `GetConfig` is the check itself: its refusal reported as a closure would start another check, whose refusal
    /// would start another one, and so on, past the bounded retries of a failed refresh.
    @Test func getConfigIsNotMarked() {
        let interceptors = ApiKeyServiceInterceptor(getUserIdBlock: { nil }, updateTokenBlock: { _ in })
            .makeGetConfigInterceptors()

        #expect(!interceptors.contains { $0 is CommunityClosedInterceptor<Com_Octopuscommunity_Empty,
                                                                           Com_Octopuscommunity_GetConfigResponse> })
    }

    @Test func anotherCallIsMarked() {
        let interceptors = TrackingServiceInterceptor(getUserIdBlock: { nil }, updateTokenBlock: { _ in })
            .makeTrackInterceptors()

        #expect(interceptors.contains { $0 is CommunityClosedInterceptor<Com_Octopuscommunity_TrackRequest,
                                                                          Com_Octopuscommunity_TrackResponse> })
    }

    // MARK: Reporting it

    @Test func aRefusalNamingTheClosureIsReported() async {
        let counter = Counter()
        let status = CommunityClosedRefusal.mark(GRPCStatus(code: .permissionDenied, message: "Closed"),
                                                 trailers: closedTrailers)

        await call(makeClient(reports: counter), failingWith: status)

        #expect(counter.value == 1)
    }

    /// The config is not asked again for a refusal of another nature.
    @Test func aPermissionDeniedNamingNoReasonIsNotReported() async {
        let counter = Counter()

        await call(makeClient(reports: counter), failingWith: GRPCStatus(code: .permissionDenied, message: "Denied"))

        #expect(counter.value == 0)
    }

    @Test(arguments: [GRPCStatus.Code.unauthenticated, .notFound, .unavailable, .internalError])
    func anotherFailureIsNotReported(code: GRPCStatus.Code) async {
        let counter = Counter()

        await call(makeClient(reports: counter), failingWith: GRPCStatus(code: code, message: nil))

        #expect(counter.value == 0)
    }

    /// A blocked call was never sent: the server refused nothing.
    @Test func aBlockedCallIsNotReported() async {
        let counter = Counter()
        let gate = CallsGate()
        gate.isBlocked = true
        let client = ServiceClient(apiKey: "api-key", sdkVersion: "1.16.0", installId: "install-id",
                                   localeIdentifier: "fr_FR",
                                   sdkIdentity: { SdkIdentity(family: .native, version: "1.16.0") },
                                   callsGate: gate)
        client.set(communityClosedHandler: { counter.value += 1 })

        await call(client, failingWith: CommunityClosedRefusal.mark(GRPCStatus(code: .permissionDenied, message: nil),
                                                                    trailers: closedTrailers))

        #expect(counter.value == 0)
    }
}
