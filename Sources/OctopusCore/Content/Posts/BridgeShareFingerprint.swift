//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CryptoKit

/// Computes the bridge "Share" image fingerprint.
///
/// When a community forbids member pictures, a prefilled (host-app) share that carries an image is
/// rejected server-side unless the post is signed. The SDK computes this fingerprint, the host signs
/// it (JWT HS256, `bridge_fingerprint` claim) and the SDK sends it as `PutPost.clientToken`.
///
/// The computation MUST match the backend `PrefilledShareVerifier` exactly: a compact JSON object of
/// the non-empty fields below, keys in alphabetical order, no spaces, then SHA-256 (lowercase hex).
/// When the CTA label is given per language, the object also holds `ctaTextLanguage` (the code of the
/// language of `ctaText`) and `ctaTextTranslations` (an object of the other labels by language code,
/// keys sorted by the bytes of their UTF-8 form). Without such labels, both keys are left out.
/// The host-side signing is documented at
/// https://doc.octopuscommunity.com/backend/jwt/generate_jwt#generate-jwt-for-a-bridge-share-with-an-image
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

    static func compute(text: String?, ctaText: String?, ctaTargetLink: String?,
                        ctaLabels: PerLanguageLabels? = nil, images: [Image]) -> String {
        let encoder = JSONEncoder()
        // Unescaped slashes + compact (no spaces/newlines) → matches the BE string.
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let json = (try? signedContent(text: text, ctaText: ctaText, ctaTargetLink: ctaTargetLink,
                                       ctaLabels: ctaLabels, images: images, encoder: encoder)) ?? Data()
        return SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined()
    }

    /// The JSON object that is hashed. It is written key by key, in alphabetical order, rather than left to the
    /// sorted keys of `JSONEncoder`: the nested `ctaTextTranslations` object needs an order the encoder does not
    /// give on every OS version (see `PerLanguageLabels.signedTranslationsJSON`).
    private static func signedContent(text: String?, ctaText: String?, ctaTargetLink: String?,
                                      ctaLabels: PerLanguageLabels?, images: [Image],
                                      encoder: JSONEncoder) throws -> Data {
        // Only non-empty fields are included (never sent as "" or null).
        var fields: [(key: String, value: Data)] = []
        if let ctaTargetLink, !ctaTargetLink.isEmpty {
            fields.append(("ctaTargetLink", try encoder.encode(ctaTargetLink)))
        }
        if let ctaText, !ctaText.isEmpty {
            fields.append(("ctaText", try encoder.encode(ctaText)))
            if let ctaLabels {
                fields.append(("ctaTextLanguage", try encoder.encode(ctaLabels.defaultLanguageCode)))
                if let translations = try ctaLabels.signedTranslationsJSON(encoder: encoder) {
                    fields.append(("ctaTextTranslations", translations))
                }
            }
        }
        if !images.isEmpty { fields.append(("image", try encoder.encode(joinedImageValue(for: images)))) }
        if let text, !text.isEmpty { fields.append(("text", try encoder.encode(text))) }

        var json = Data("{".utf8)
        for (index, field) in fields.enumerated() {
            if index > 0 { json.append(UInt8(ascii: ",")) }
            json.append(try encoder.encode(field.key))
            json.append(UInt8(ascii: ":"))
            json.append(field.value)
        }
        json.append(UInt8(ascii: "}"))
        return json
    }
}
