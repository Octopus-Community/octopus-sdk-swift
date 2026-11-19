//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import CryptoKit
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

    /// Canonical vector with button labels per language, from the same page of the public documentation.
    func testFingerprintWithPerLanguageLabelsMatchesDocumentationVector() {
        let fingerprint = BridgeShareFingerprint.compute(
            text: "Check out our new recipe!",
            ctaText: "Learn more",
            ctaTargetLink: "https://shop.example.com/item/42",
            ctaLabels: PerLanguageLabels(defaultLanguageCode: "en",
                                         translations: ["pt-BR": "Saiba mais", "fr": "En savoir plus"]),
            images: [.url("https://cdn.example.com/share-banner.png")])

        XCTAssertEqual(fingerprint, "281bdd8d72715eb71f87a88e7ad4697d3388252a2eb8032e82aaadd936758587")
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

    /// Vector shared with the Android SDK and the backend: the SHA-256 of
    /// `{"ctaTargetLink":"https://shop.example.com/item/42","ctaText":"Start","ctaTextLanguage":"en",`
    /// `"ctaTextTranslations":{"en-US":"Start now","es-419":"Empezar","fr":"Démarrer","zh-HK":"開始",`
    /// `"zh-Hant-TW":"開始"},"image":"https://cdn.example.com/share-banner.png","text":"Check out our new recipe!"}`.
    ///
    /// The labels are given out of order, and `zh-HK` comes before `zh-Hant-TW` only when the codes are compared
    /// by their bytes: without case, `zh-Hant-TW` would come first.
    func testFingerprintWithPerLanguageLabelsMatchesSharedVector() {
        let fingerprint = BridgeShareFingerprint.compute(
            text: "Check out our new recipe!",
            ctaText: "Start",
            ctaTargetLink: "https://shop.example.com/item/42",
            ctaLabels: PerLanguageLabels(defaultLanguageCode: "en", translations: [
                "zh-Hant-TW": "開始",
                "fr": "Démarrer",
                "zh-HK": "開始",
                "es-419": "Empezar",
                "en-US": "Start now"
            ]),
            images: [.url("https://cdn.example.com/share-banner.png")])

        XCTAssertEqual(fingerprint, "fe738796db97fc7bafb9a4476165b10f4a82de2fbf84ed66a3a3e24136122bd4")
    }

    /// The vector pinned by the backend tests: the SHA-256 of
    /// `{"ctaTargetLink":"https://client.example/item/42","ctaText":"Start","ctaTextLanguage":"en",`
    /// `"ctaTextTranslations":{"en-US":"Get started","es-419":"Empezar","fr":"Démarrer","zh-CN":"开始"},`
    /// `"image":"https://client.example/img.png","text":"shared text"}`, with the labels given out of order.
    func testFingerprintWithPerLanguageLabelsMatchesBackendVector() {
        let fingerprint = BridgeShareFingerprint.compute(
            text: "shared text",
            ctaText: "Start",
            ctaTargetLink: "https://client.example/item/42",
            ctaLabels: PerLanguageLabels(defaultLanguageCode: "en", translations: [
                "zh-CN": "开始",
                "fr": "Démarrer",
                "es-419": "Empezar",
                "en-US": "Get started"
            ]),
            images: [.url("https://client.example/img.png")])

        XCTAssertEqual(fingerprint, "85e80c5f8529a88430e4a69383512c9ef507633ce5f1ca2046d7e0401c46d4cc")
    }

    /// The same share without per-language labels, as pinned by the backend tests: the two keys are left out.
    func testFingerprintWithoutPerLanguageLabelsMatchesBackendVector() {
        let fingerprint = BridgeShareFingerprint.compute(
            text: "shared text",
            ctaText: "Start",
            ctaTargetLink: "https://client.example/item/42",
            images: [.url("https://client.example/img.png")])

        XCTAssertEqual(fingerprint, "eb92be3d14da5eabf3e7f79e63d001c767ee23d6a4cfef80051d959953f84272")
    }

    /// With a label for the default language only, the language is signed and the translations are left out.
    func testFingerprintWithDefaultLanguageOnlyOmitsTheTranslations() {
        let fingerprint = BridgeShareFingerprint.compute(
            text: "Check out our new recipe!",
            ctaText: "Start",
            ctaTargetLink: "https://shop.example.com/item/42",
            ctaLabels: PerLanguageLabels(defaultLanguageCode: "en", translations: [:]),
            images: [.url("https://cdn.example.com/share-banner.png")])

        let expectedJson = #"{"ctaTargetLink":"https://shop.example.com/item/42","ctaText":"Start","#
            + #""ctaTextLanguage":"en","image":"https://cdn.example.com/share-banner.png","#
            + #""text":"Check out our new recipe!"}"#
        XCTAssertEqual(fingerprint, Self.sha256(expectedJson))
    }

    /// Slashes stay unescaped and quotes are escaped in the labels and codes, as in the other fields.
    func testFingerprintEscapesPerLanguageLabelsLikeTheOtherFields() {
        let fingerprint = BridgeShareFingerprint.compute(
            text: nil,
            ctaText: "Start",
            ctaTargetLink: nil,
            ctaLabels: PerLanguageLabels(defaultLanguageCode: "en", translations: ["fr": #"Voir "a/b""#]),
            images: [.url("https://a.png")])

        let expectedJson = #"{"ctaText":"Start","ctaTextLanguage":"en","#
            + #""ctaTextTranslations":{"fr":"Voir \"a/b\""},"image":"https://a.png"}"#
        XCTAssertEqual(fingerprint, Self.sha256(expectedJson))
    }

    private static func sha256(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
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
