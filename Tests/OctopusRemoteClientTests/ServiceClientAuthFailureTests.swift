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
@testable import OctopusRemoteClient

/// When does `ServiceClient.callRemote` drop the session on an `unauthenticated` answer?
///
/// A banned user gets `unauthenticated` with the ban reason as message, localized in their language. That
/// user must keep their session so the message can be displayed. Only an expired token must trigger
/// `authFailure`.
@Suite("ServiceClient.callRemote auth failure")
struct ServiceClientAuthFailureTests {

    /// Mutable flag usable from the non-`Sendable` `authFailure` closure.
    private final class Flag: @unchecked Sendable {
        var isSet = false
    }

    private func makeClient(locale: String = "fr_FR") -> ServiceClient {
        ServiceClient(apiKey: "api-key", sdkVersion: "1.13.2", installId: "install-id",
                      localeIdentifier: locale)
    }

    /// Runs `callRemote` with a failing block and returns whether `authFailure` was called.
    private func authFailureCalled(
        on error: Error, token: String?
    ) async -> Bool {
        let flag = Flag()
        let method: AuthenticationMethod = if let token {
            .authenticated(token: token, authFailure: { flag.isSet = true })
        } else {
            .notAuthenticated
        }
        do {
            let _: Int = try await makeClient().callRemote(method) { throw error }
            Issue.record("callRemote should have rethrown the error")
        } catch {
            // expected: the error is always rethrown, wrapped in a RemoteClientError
        }
        return flag.isSet
    }

    // MARK: Banned user — the session must survive, whatever the locale

    /// The ban message is localized. Before the fix, only the English wording was recognized and users
    /// in the 8+ other locales were logged out instead of seeing why they were banned.
    @Test(arguments: [
        "Your account has been blocked for the following reason: spam",
        "Votre compte a été bloqué pour le motif suivant : spam",
        "Ihr Konto wurde aus folgendem Grund gesperrt: Spam",
        "La tua utenza è stata bloccata per il seguente motivo: spam",
        "Twoje konto zostało zablokowane z następującego powodu: spam",
        "Hesabınız aşağıdaki nedenle bloke edilmiştir: spam"
    ])
    func bannedUserWithValidTokenKeepsSession(banMessage: String) async {
        let called = await authFailureCalled(
            on: GRPCStatus(code: .unauthenticated, message: banMessage),
            token: TestJwt.expiring(in: 3600))
        #expect(called == false)
    }

    /// Same guarantee when the server sends no message at all.
    @Test func unauthenticatedWithoutMessageAndValidTokenKeepsSession() async {
        let called = await authFailureCalled(
            on: GRPCStatus(code: .unauthenticated, message: nil),
            token: TestJwt.expiring(in: 3600))
        #expect(called == false)
    }

    // MARK: Expired token — the session must be renewed

    @Test func expiredTokenTriggersAuthFailure() async {
        let called = await authFailureCalled(
            on: GRPCStatus(code: .unauthenticated, message: "invalid token"),
            token: TestJwt.expiring(in: -60))
        #expect(called == true)
    }

    /// Fallback: an unreadable expiration keeps the pre-fix behaviour rather than guessing.
    @Test(arguments: ["not-a-jwt", ""])
    func tokenWithoutReadableExpirationTriggersAuthFailure(token: String) async {
        let called = await authFailureCalled(
            on: GRPCStatus(code: .unauthenticated, message: "invalid token"),
            token: token)
        #expect(called == true)
    }

    // MARK: Other errors never touch the session

    @Test(arguments: [GRPCStatus.Code.permissionDenied, .notFound, .internalError, .unavailable])
    func otherStatusCodesDoNotTriggerAuthFailure(code: GRPCStatus.Code) async {
        let called = await authFailureCalled(
            on: GRPCStatus(code: code, message: "nope"),
            token: TestJwt.expiring(in: -60))
        #expect(called == false)
    }

    @Test func nonGrpcErrorDoesNotTriggerAuthFailure() async {
        struct Whatever: Error { }
        let called = await authFailureCalled(on: Whatever(), token: TestJwt.expiring(in: -60))
        #expect(called == false)
    }

    @Test func unauthenticatedCallWithoutTokenHasNothingToFail() async {
        let called = await authFailureCalled(
            on: GRPCStatus(code: .unauthenticated, message: "invalid token"), token: nil)
        #expect(called == false)
    }
}
