//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import CryptoKit
import Foundation
import OctopusGrpcModels
import Testing
@testable import OctopusCore

@Suite
class ClientPostTests {
    @Test func hashClientPostWithNullValues() throws {
        let clientPost = ClientPost(
            clientObjectId: "a7dada1c-f933-4186-9e72-88927ef3bf90",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [],
            viewClientObjectButtonText: nil
        )

        try #expect(clientPost.getHashForSignature() == "44928831e861ca52f0ea8be57a394e9f966a1bc8b19709ad80bd033d1a833232")
    }

    @Test func hashClientPostWithRemoteImage() throws {
        let clientPost = ClientPost(
            clientObjectId: "a7dada1c-f933-4186-9e72-88927ef3bf90",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [.distantImage(URL(string: "https://media-content-dev.octocdn.net/sample_640%C3%97426.jpeg")!)],
            viewClientObjectButtonText: "see item"
        )

        try #expect(clientPost.getHashForSignature() == "f3477a91dbf0948c3308df583d070647193b9bfcb08cc0281827204f5927bcb7")
    }

    @Test func hashClientPostWithLocalImage() throws {
        let imageUrl = try #require(Bundle.module.url(forResource: "clientPostImg1", withExtension: "png"))
        let imageData = try Data(contentsOf: imageUrl)
        let clientPost = ClientPost(
            clientObjectId: "ea2ebba8-c2d6-4945-95e7-1c2eafd97c2e",
            groupId: nil,
            text: "Text here",
            catchPhrase: "What do you think ?",
            medias: [.localImage(imageData)],
            viewClientObjectButtonText: "see item"
        )

        try #expect(clientPost.getHashForSignature() == "8136cbd29dc13bdf22eeffccbe890d16910ff38ed865e1a70a520d668a675204")
    }

    @Test func hashClientPostWithTopic() throws {
        let imageUrl = try #require(Bundle.module.url(forResource: "clientPostImg2", withExtension: "jpeg"))
        let imageData = try Data(contentsOf: imageUrl)
        let clientPost = ClientPost(
            clientObjectId: "570c32e4-5179-44f1-9ed6-95b92ed885d6",
            groupId: "a1snSDVg0BRLQHZ-qKrdPS",
            text: "Text here",
            catchPhrase: "What do you think ?",
            medias: [.localImage(imageData)],
            viewClientObjectButtonText: "see item"
        )

        try #expect(clientPost.getHashForSignature() == "3837e589f323ba0d701ce2d2a19fd4b559e4ba180f9932e5d32b583402da97be")
    }

    @Test func hashClientPostWithTwoImages() throws {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [
                .distantImage(URL(string: "https://a.example/1.jpg")!),
                .distantImage(URL(string: "https://a.example/2.jpg")!)
            ],
            viewClientObjectButtonText: nil
        )

        let expectedJson = #"{"clientObjectId":"id","image":"https://a.example/1.jpg, https://a.example/2.jpg","#
            + #""text":"Text here"}"#
        let expectedHash = SHA256.hash(data: Data(expectedJson.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        try #expect(clientPost.getHashForSignature() == expectedHash)
    }

    @Test func hashClientPostWithMixedLocalAndDistantImagesKeepsTheirOrder() throws {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [
                .localImage(Data([0xfb, 0xff])),
                .distantImage(URL(string: "https://a.example/2.jpg")!),
                .localImage(Data([0xff, 0xfe, 0xfd, 0xfc]))
            ],
            viewClientObjectButtonText: nil
        )

        // Standard Base64 of the local bytes is "+/8=" and "//79/A==": the signature uses the URL-safe alphabet
        // and drops the padding.
        let expectedJson = #"{"clientObjectId":"id","image":"-_8, https://a.example/2.jpg, __79_A","#
            + #""text":"Text here"}"#
        let expectedHash = SHA256.hash(data: Data(expectedJson.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        try #expect(clientPost.getHashForSignature() == expectedHash)
    }

    /// The fingerprint is hashed piece by piece; it must stay the SHA-256 of the whole JSON, as the back computes it.
    @Test(arguments: [0, 1, 2, 3, 49_151, 49_152, 49_153, 2 * 49_152 + 1])
    func streamedHashIsTheHashOfTheWholeJson(localImageSize: Int) throws {
        let bytes = Data((0..<localImageSize).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
        let clientPost = ClientPost(
            clientObjectId: "id \"quoted\" é",
            groupId: "group/1",
            text: "Text with \\ a backslash, a / slash and a line\nbreak",
            catchPhrase: "Catch",
            medias: [
                .localImage(bytes),
                .distantImage(URL(string: "https://a.example/path/2.jpg?size=big&format=jpg")!),
                .localImage(Data([0xfb, 0xff, 0xfe]))
            ],
            viewClientObjectButtonText: "See"
        )

        #expect(try clientPost.getHashForSignature() == Self.hashOfWholeJson(clientPost))
    }

    @Test func streamedHashWithoutMediaIsTheHashOfTheWholeJson() throws {
        let clientPost = ClientPost(clientObjectId: "id", groupId: nil, text: "Text here", catchPhrase: nil,
                                    medias: [], viewClientObjectButtonText: nil)
        #expect(try clientPost.getHashForSignature() == Self.hashOfWholeJson(clientPost))
    }

    @Test func hashClientPostWithPerLanguageLabelsSortsTheCodesByBytes() throws {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: "group",
            text: "Text here",
            catchPhrase: "Catch",
            medias: [],
            viewClientObjectButtonText: "Start",
            viewClientObjectButtonLabels: Self.labels
        )

        let expectedJson = #"{"catchPhrase":"Catch","clientObjectId":"id","ctaText":"Start","ctaTextLanguage":"en","#
            + Self.signedTranslations + #","text":"Text here","topicId":"group"}"#
        #expect(try clientPost.getHashForSignature() == Self.sha256(expectedJson))
    }

    @Test func hashClientPostWithPerLanguageLabelsAndImages() throws {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [.localImage(Data([0xfb, 0xff])), .distantImage(URL(string: "https://a.example/2.jpg")!)],
            viewClientObjectButtonText: "Start",
            viewClientObjectButtonLabels: Self.labels
        )

        let expectedJson = #"{"clientObjectId":"id","ctaText":"Start","ctaTextLanguage":"en","#
            + Self.signedTranslations + #","image":"-_8, https://a.example/2.jpg","text":"Text here"}"#
        #expect(try clientPost.getHashForSignature() == Self.sha256(expectedJson))
    }

    /// The vector pinned by the backend tests: the SHA-256 of
    /// `{"catchPhrase":"Tell us!","clientObjectId":"object-1","ctaText":"Start","ctaTextLanguage":"en",`
    /// `"ctaTextTranslations":{"en-US":"Get started","es-419":"Empezar","fr":"Démarrer","zh-CN":"开始"},`
    /// `"image":"https://client.example/img.png","text":"A drawing","topicId":"topic-1"}`, with the labels given
    /// out of order.
    @Test func hashClientPostWithPerLanguageLabelsMatchesBackendVector() throws {
        let clientPost = ClientPost(
            clientObjectId: "object-1",
            groupId: "topic-1",
            text: "A drawing",
            catchPhrase: "Tell us!",
            medias: [.distantImage(try #require(URL(string: "https://client.example/img.png")))],
            viewClientObjectButtonText: "Start",
            viewClientObjectButtonLabels: PerLanguageLabels(defaultLanguageCode: "en", translations: [
                "zh-CN": "开始",
                "fr": "Démarrer",
                "es-419": "Empezar",
                "en-US": "Get started"
            ])
        )

        #expect(try clientPost.getHashForSignature()
                == "49416d89b9d0b2117e3c9dab57f77a7669f0e968921b750df1e54c6599db79c4")
    }

    /// The example with button labels per language of the public documentation on generating a bridge JWT.
    @Test func hashClientPostWithPerLanguageLabelsMatchesDocumentationVector() throws {
        let clientPost = ClientPost(
            clientObjectId: "recipe-129302938",
            groupId: "topicId",
            text: "The perfects Canelés",
            catchPhrase: "Tried the canelés? Tell us how good they were!",
            medias: [.distantImage(try #require(URL(string: "https://cdn.example.com/images/bridge-banner.png")))],
            viewClientObjectButtonText: "Learn more",
            viewClientObjectButtonLabels: PerLanguageLabels(defaultLanguageCode: "en", translations: [
                "pt-BR": "Saiba mais",
                "fr": "En savoir plus",
                "de": "Mehr erfahren"
            ])
        )

        #expect(try clientPost.getHashForSignature()
                == "c9f24aa9eacdad47e5697d41c52d991d85620fe04fd269fb473715e48ea3cc89")
    }

    @Test func hashClientPostWithDefaultLanguageOnlyOmitsTheTranslations() throws {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [],
            viewClientObjectButtonText: "Start",
            viewClientObjectButtonLabels: PerLanguageLabels(defaultLanguageCode: "en", translations: [:])
        )

        let expectedJson = #"{"clientObjectId":"id","ctaText":"Start","ctaTextLanguage":"en","text":"Text here"}"#
        #expect(try clientPost.getHashForSignature() == Self.sha256(expectedJson))
    }

    @Test func hashClientPostEscapesPerLanguageLabelsLikeTheOtherFields() throws {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [],
            viewClientObjectButtonText: "Start",
            viewClientObjectButtonLabels: PerLanguageLabels(
                defaultLanguageCode: "en", translations: ["fr": #"Voir "a/b""#])
        )

        let expectedJson = #"{"clientObjectId":"id","ctaText":"Start","ctaTextLanguage":"en","#
            + #""ctaTextTranslations":{"fr":"Voir \"a/b\""},"text":"Text here"}"#
        #expect(try clientPost.getHashForSignature() == Self.sha256(expectedJson))
    }

    @Test func perLanguageLabelsLeaveTheDefaultLanguageOutOfTheTranslations() {
        let labels = PerLanguageLabels(defaultLanguageCode: "en",
                                       textsByLanguageCode: ["en": "Start", "fr": "Démarrer"])

        #expect(labels == PerLanguageLabels(defaultLanguageCode: "en", translations: ["fr": "Démarrer"]))
    }

    @Test func rwOctoPostSendsThePerLanguageLabels() {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [],
            viewClientObjectButtonText: "Start",
            viewClientObjectButtonLabels: PerLanguageLabels(
                defaultLanguageCode: "en", translations: ["fr": "Démarrer"])
        )

        let cta = clientPost.rwOctoPost(imagesAreCompressed: []).bridgeToClientObject.cta
        #expect(cta.text == "Start")
        #expect(cta.textLanguage == "en")
        #expect(cta.textTranslations == ["fr": "Démarrer"])
    }

    @Test func rwOctoPostSendsNoLanguageWithoutPerLanguageLabels() {
        let clientPost = ClientPost(clientObjectId: "id", groupId: nil, text: "Text here", catchPhrase: nil,
                                    medias: [], viewClientObjectButtonText: "Start")

        let cta = clientPost.rwOctoPost(imagesAreCompressed: []).bridgeToClientObject.cta
        #expect(cta.text == "Start")
        #expect(!cta.hasTextLanguage)
        #expect(cta.textTranslations.isEmpty)
    }

    /// Labels given out of order, with codes whose order depends on how they are compared: by bytes, `en` comes
    /// before `en-US` and `zh-HK` before `zh-Hant-TW`.
    private static let labels = PerLanguageLabels(defaultLanguageCode: "en", translations: [
        "zh-Hant-TW": "開始",
        "fr": "Démarrer",
        "zh-HK": "開始",
        "es-419": "Empezar",
        "en-US": "Start now"
    ])

    private static let signedTranslations = #""ctaTextTranslations":{"en-US":"Start now","es-419":"Empezar","#
        + #""fr":"Démarrer","zh-HK":"開始","zh-Hant-TW":"開始"}"#

    private static func sha256(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The fingerprint as it was computed before it was streamed: the SHA-256 of the whole encoded JSON.
    private static func hashOfWholeJson(_ clientPost: ClientPost) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hash(data: try encoder.encode(clientPost)).map { String(format: "%02x", $0) }.joined()
    }

    @Test func rwOctoPostEmitsEveryImageInOrder() throws {
        let localData = Data([1, 2, 3])
        let remoteUrl = URL(string: "https://a.example/2.jpg")!
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [.localImage(localData), .distantImage(remoteUrl)],
            viewClientObjectButtonText: nil
        )

        let images = clientPost.rwOctoPost(imagesAreCompressed: [true, false]).media.images
        #expect(images.count == 2)
        #expect(images[0].file == .bytes(localData))
        #expect(images[0].isOptimized)
        #expect(images[1].file == .url(remoteUrl.absoluteString))
    }

    @Test func rwOctoPostReferencesLocalImagesByUploadIdAndKeepsDistantUrls() throws {
        let remoteUrl = URL(string: "https://a.example/2.jpg")!
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [.localImage(Data([1])), .distantImage(remoteUrl), .localImage(Data([2]))],
            viewClientObjectButtonText: nil
        )

        #expect(clientPost.localImages == [Data([1]), Data([2])])
        let images = try clientPost.rwOctoPost(uploadIds: ["id0", "id1"]).media.images
        #expect(images.map(\.file) == [.uploadID("id0"), .url(remoteUrl.absoluteString), .uploadID("id1")])
        #expect(images[0].isOptimized)
        #expect(images[2].isOptimized)
    }

    @Test(arguments: [[], ["id0"], ["id0", "id1", "id2"]])
    func rwOctoPostRefusesAnUploadIdsCountThatDoesNotMatchTheLocalImages(uploadIds: [String]) {
        let clientPost = ClientPost(
            clientObjectId: "id",
            groupId: nil,
            text: "Text here",
            catchPhrase: nil,
            medias: [.localImage(Data([1])), .distantImage(URL(string: "https://a.example/2.jpg")!),
                     .localImage(Data([2]))],
            viewClientObjectButtonText: nil
        )

        #expect(throws: InternalError.self) { try clientPost.rwOctoPost(uploadIds: uploadIds) }
    }
}
