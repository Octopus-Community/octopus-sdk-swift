//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusRemoteClient

/// While the community is closed, no call may reach the server: `callRemote` fails before running the call, unless
/// the caller explicitly bypasses the gate (the config check that learns whether the community reopened).
@Suite("ServiceClient.callRemote calls gate")
struct CallsGateTests {

    /// Mutable counter usable from the non-`Sendable` closures of `callRemote`.
    private final class Counter: @unchecked Sendable {
        var value = 0
    }

    private func makeClient(gate: CallsGate) -> ServiceClient {
        ServiceClient(apiKey: "api-key", sdkVersion: "1.16.0", installId: "install-id",
                      localeIdentifier: "fr_FR",
                      sdkIdentity: { SdkIdentity(family: .native, version: "1.16.0") },
                      callsGate: gate)
    }

    @Test func aBlockedGateFailsTheCallWithoutRunningIt() async {
        let gate = CallsGate()
        gate.isBlocked = true
        let counter = Counter()

        do {
            let _: Int = try await makeClient(gate: gate).callRemote(.notAuthenticated) {
                counter.value += 1
                return 1
            }
            Issue.record("callRemote should have failed")
        } catch {
            #expect(error.isCallsBlocked)
        }
        #expect(counter.value == 0)
    }

    @Test func aBlockedGateLetsABypassingCallThrough() async throws {
        let gate = CallsGate()
        gate.isBlocked = true

        let value: Int = try await makeClient(gate: gate).callRemote(.notAuthenticated, bypassingCallsGate: true) {
            42
        }

        #expect(value == 42)
    }

    /// A blocked call is not an answer of the server: it must not be read as an expired session.
    @Test func aBlockedCallDoesNotDropTheSession() async {
        let gate = CallsGate()
        gate.isBlocked = true
        let authFailures = Counter()
        // A token whose `exp` is in the past.
        let expiredToken = "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjF9.c2lnbmF0dXJl"

        do {
            let _: Int = try await makeClient(gate: gate).callRemote(
                .authenticated(token: expiredToken, authFailure: { authFailures.value += 1 })) { 1 }
            Issue.record("callRemote should have failed")
        } catch {
            #expect(error.isCallsBlocked)
        }
        #expect(authFailures.value == 0)
    }

    @Test func anOpenGateRunsTheCall() async throws {
        let value: Int = try await makeClient(gate: CallsGate()).callRemote(.notAuthenticated) { 7 }

        #expect(value == 7)
    }
}
