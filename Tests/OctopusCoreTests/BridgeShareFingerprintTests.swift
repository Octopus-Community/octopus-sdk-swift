//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
@testable import OctopusCore

/// The bridge "Share" image fingerprint, which lets a signed prefilled share carry an image even in a
/// community that disables pictures. MUST match the backend `PrefilledShareVerifier` byte-for-byte —
/// verified against the canonical example of the public documentation:
/// https://doc.octopuscommunity.com/backend/jwt/generate_jwt#generate-jwt-for-a-bridge-share-with-an-image
final class BridgeShareFingerprintTests: XCTestCase {

    /// Canonical vector from the public documentation linked above (image URL case).
    func testFingerprintMatchesDocumentationVector() {
        let fingerprint = BridgeShareFingerprint.compute(
            text: "Check out our new recipe!",
            ctaText: "Learn more",
            ctaTargetLink: "https://shop.example.com/item/42",
            images: [.url("https://cdn.example.com/share-banner.png")])

        XCTAssertEqual(fingerprint, "8057af48049d1bcda406ab16622422f34a978a54856cac5e7091a082bf481046")
    }

    /// Empty optional fields are omitted entirely (not sent as "" or null).
    func testEmptyOptionalFieldsAreOmitted() {
        // Same as the doc's "warning" example: {"image":"…","text":"…"}.
        let withEmpty = BridgeShareFingerprint.compute(
            text: "Check out our new recipe!",
            ctaText: "",
            ctaTargetLink: nil,
            images: [.url("https://cdn.example.com/share-banner.png")])
        let withoutCta = BridgeShareFingerprint.compute(
            text: "Check out our new recipe!",
            ctaText: nil,
            ctaTargetLink: nil,
            images: [.url("https://cdn.example.com/share-banner.png")])

        XCTAssertEqual(withEmpty, withoutCta)
    }

    /// Raw image bytes are encoded as URL-safe Base64 without padding.
    func testImageBytesUseUrlSafeBase64WithoutPadding() {
        // 0xFB 0xFF 0xFE → standard Base64 "+//+" ; URL-safe no-pad → "-__-"
        let bytes = Data([0xFB, 0xFF, 0xFE])
        let single = BridgeShareFingerprint.imageValue(for: .bytes(bytes))
        XCTAssertEqual(single, "-__-")
        XCTAssertFalse(single.contains("="))
        XCTAssertFalse(single.contains("+"))
        XCTAssertFalse(single.contains("/"))
    }

    /// Multiple images join their values with ", " in order.
    func testMultipleImagesJoinedWithCommaSpace() {
        let joined = BridgeShareFingerprint.joinedImageValue(
            for: [.url("https://a.png"), .url("https://b.png")])
        XCTAssertEqual(joined, "https://a.png, https://b.png")
    }
}
