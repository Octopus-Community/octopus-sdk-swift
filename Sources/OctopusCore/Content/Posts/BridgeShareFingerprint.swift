//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CryptoKit

/// Computes the bridge "Share" image fingerprint (OCT-1426 / Q5).
///
/// When a community forbids member pictures, a prefilled (host-app) share that carries an image is
/// rejected server-side unless the post is signed. The SDK computes this fingerprint, the host signs
/// it (JWT HS256, `bridge_fingerprint` claim) and the SDK sends it as `PutPost.clientToken`.
///
/// The computation MUST match the backend `PrefilledShareVerifier` exactly (octopus-documentation #60):
/// a compact JSON object of the non-empty fields below, keys in alphabetical order, no spaces, then
/// SHA-256 (lowercase hex).
enum BridgeShareFingerprint {
    enum Image {
        /// An already-hosted image URL.
        case url(String)
        /// Raw image bytes — encoded as URL-safe Base64 without padding.
        case bytes(Data)
    }

    /// The `image` value for a single image: the URL verbatim, or the bytes as URL-safe Base64 (no padding).
    static func imageValue(for image: Image) -> String {
        switch image {
        case let .url(url):
            return url
        case let .bytes(data):
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }

    /// The combined `image` field: each image's value joined with ", " (comma + space), in order.
    static func joinedImageValue(for images: [Image]) -> String {
        images.map(imageValue(for:)).joined(separator: ", ")
    }

    static func compute(text: String?, ctaText: String?, ctaTargetLink: String?, images: [Image]) -> String {
        // Only non-empty fields are included (never sent as "" or null).
        var fields: [String: String] = [:]
        if let text, !text.isEmpty { fields["text"] = text }
        if let ctaText, !ctaText.isEmpty { fields["ctaText"] = ctaText }
        if let ctaTargetLink, !ctaTargetLink.isEmpty { fields["ctaTargetLink"] = ctaTargetLink }
        if !images.isEmpty { fields["image"] = joinedImageValue(for: images) }

        let encoder = JSONEncoder()
        // Alphabetical keys + unescaped slashes + compact (no spaces/newlines) → matches the BE string.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = (try? encoder.encode(fields)) ?? Data()
        return SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined()
    }
}
