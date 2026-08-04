//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Reads claims of a JWT without validating its signature.
///
/// Only used to tell apart the two very different reasons the server answers `unauthenticated` on an
/// authenticated call: an expired token (the session must be renewed) and a business refusal such as a
/// banned user (the session must be kept so the message can be displayed). The claim is never used to
/// grant anything — the server stays the only authority.
enum Jwt {
    /// Whether `token` is expired at `now`, according to its `exp` claim.
    ///
    /// Returns `nil` when the expiration cannot be determined (not a JWT, unreadable payload, no `exp`
    /// claim) so that callers can fall back to their own default instead of guessing.
    static func isExpired(_ token: String, now: Date = Date()) -> Bool? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let payloadData = base64UrlDecoded(String(parts[1])),
              let payload = (try? JSONSerialization.jsonObject(with: payloadData)) as? [String: Any],
              let exp = payload["exp"] as? Double
        else { return nil }
        return Date(timeIntervalSince1970: exp) <= now
    }

    /// Decodes a base64url string (JWT flavor: `-`/`_` alphabet, padding omitted).
    private static func base64UrlDecoded(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
