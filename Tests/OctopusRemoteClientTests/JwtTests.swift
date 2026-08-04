//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusRemoteClient

/// Forges unsigned JWTs for the tests of this target (the SDK only reads the payload, it never verifies
/// the signature, so a dummy one is enough).
enum TestJwt {
    /// A JWT whose payload is `claims`, base64url encoded without padding.
    static func make(claims: [String: Any]) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: claims)
        return "\(base64Url(Data("{\"alg\":\"HS256\"}".utf8))).\(base64Url(payload)).signature"
    }

    /// A JWT expiring `interval` seconds from now (negative interval → already expired).
    static func expiring(in interval: TimeInterval, from now: Date = Date()) -> String {
        make(claims: ["exp": now.addingTimeInterval(interval).timeIntervalSince1970])
    }

    private static func base64Url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@Suite("Jwt.isExpired")
struct JwtTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func expiredTokenIsExpired() {
        let token = TestJwt.make(claims: ["exp": now.timeIntervalSince1970 - 60])
        #expect(Jwt.isExpired(token, now: now) == true)
    }

    @Test func validTokenIsNotExpired() {
        let token = TestJwt.make(claims: ["exp": now.timeIntervalSince1970 + 3600])
        #expect(Jwt.isExpired(token, now: now) == false)
    }

    @Test func expirationExactlyNowIsExpired() {
        let token = TestJwt.make(claims: ["exp": now.timeIntervalSince1970])
        #expect(Jwt.isExpired(token, now: now) == true)
    }

    /// `exp` is an integer in real tokens, and `JSONSerialization` hands it back as an `NSNumber`.
    @Test func integerExpirationIsRead() {
        let token = TestJwt.make(claims: ["exp": Int(now.timeIntervalSince1970) + 3600])
        #expect(Jwt.isExpired(token, now: now) == false)
    }

    /// Payload lengths that are not a multiple of 4 must still decode (JWTs drop base64 padding).
    @Test(arguments: 1...12) func payloadOfAnyLengthDecodes(subjectLength: Int) {
        let token = TestJwt.make(claims: [
            "exp": now.timeIntervalSince1970 + 3600,
            "sub": String(repeating: "a", count: subjectLength)
        ])
        #expect(Jwt.isExpired(token, now: now) == false)
    }

    // MARK: Undeterminable expiration — callers fall back to their own default

    @Test func missingExpClaimIsUndeterminable() {
        #expect(Jwt.isExpired(TestJwt.make(claims: ["sub": "user"]), now: now) == nil)
    }

    @Test func nonNumericExpClaimIsUndeterminable() {
        #expect(Jwt.isExpired(TestJwt.make(claims: ["exp": "soon"]), now: now) == nil)
    }

    @Test(arguments: ["", "not-a-jwt", "two.parts", "a.b.c.d", "header..signature"])
    func malformedTokenIsUndeterminable(token: String) {
        #expect(Jwt.isExpired(token, now: now) == nil)
    }

    @Test func nonJsonPayloadIsUndeterminable() {
        #expect(Jwt.isExpired("header.bm90LWpzb24.signature", now: now) == nil)
    }
}
