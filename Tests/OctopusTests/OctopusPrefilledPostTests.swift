//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import UIKit
import Octopus

struct OctopusPrefilledPostTests {

    // MARK: - optional text & image (Bridge Share: preselected group, empty editable fields)

    @Test func initAcceptsEmptyPayloadWhenBothNil() throws {
        let post = try OctopusPrefilledPost(text: nil, images: [])
        #expect(post.text == nil)
        #expect(post.images.isEmpty)
    }

    @Test func initAcceptsEmptyPayloadWhenBothEmpty() throws {
        // `""` / empty `Data` normalize to nil, and an empty payload is now allowed.
        let post = try OctopusPrefilledPost(text: "", images: [Data()])
        #expect(post.text == nil)
        #expect(post.images.isEmpty)
    }

    @Test func initAcceptsGroupAndCtaOnlyWithoutTextOrImage() throws {
        let post = try OctopusPrefilledPost(
            topicId: "topic-id",
            cta: try OctopusPrefilledPost.CTA(url: URL(string: "myapp://item/42")!,
                                                  localizedLabel: .autoTranslated("Open")))
        #expect(post.text == nil)
        #expect(post.images.isEmpty)
        #expect(post.topicId == "topic-id")
        #expect(post.cta?.label == "Open")
    }

    // MARK: - text validation

    @Test func initAcceptsShortText() throws {
        #expect(try OctopusPrefilledPost(text: "a").text == "a")
        #expect(try OctopusPrefilledPost(text: "Fini !").text == "Fini !")
    }

    @Test func initPassesWhitespaceOnlyTextToTheEditor() throws {
        #expect(try OctopusPrefilledPost(text: "   ").text == "   ")
    }

    @Test func initAcceptsShortTextWithImage() throws {
        let image = makeValidJpegData()
        #expect(try OctopusPrefilledPost(text: "Fini !", images: [image]).text == "Fini !")
    }

    @Test func initThrowsTextTooLong() {
        let tooLong = String(repeating: "a", count: 5001)
        #expect(throws: OctopusPrefilledPost.ValidationError.self) {
            _ = try OctopusPrefilledPost(text: tooLong)
        }
    }

    // MARK: - image validation

    @Test func initThrowsImageInvalidWhenDataNotDecodable() {
        let bogus = Data([0xFF, 0xD8])
        #expect(throws: OctopusPrefilledPost.ValidationError.imageInvalid) {
            _ = try OctopusPrefilledPost(images: [bogus])
        }
    }

    @Test func initThrowsImageTooSmall() {
        // Validators.Picture.minSize is 50. A 10×10 image has minSide < 50 → .sideTooSmall.
        let smallImage = makeJpegData(width: 10, height: 10)
        #expect(throws: OctopusPrefilledPost.ValidationError.self) {
            _ = try OctopusPrefilledPost(images: [smallImage])
        }
    }

    @Test func initThrowsImageRatioTooLarge() {
        // Validators.Picture.maxRatio is 32/9 (≈3.56). 60×400 has ratio ~6.67 → .ratioTooBig.
        let skinnyImage = makeJpegData(width: 60, height: 400)
        #expect(throws: OctopusPrefilledPost.ValidationError.self) {
            _ = try OctopusPrefilledPost(images: [skinnyImage])
        }
    }

    // MARK: - CTA validation

    @Test func ctaInitThrowsOnEmptyLabel() {
        #expect(throws: OctopusPrefilledPost.ValidationError.ctaLabelEmpty) {
            _ = try OctopusPrefilledPost.CTA(url: URL(string: "https://example.com")!,
                                             localizedLabel: .autoTranslated("  "))
        }
    }

    // MARK: - happy path

    @Test func initAcceptsTextOnly() throws {
        let post = try OctopusPrefilledPost(text: "hello world long enough")
        #expect(post.text == "hello world long enough")
        #expect(post.images.isEmpty)
        #expect(post.topicId == nil)
        #expect(post.cta == nil)
    }

    @Test func initAcceptsImageOnly() throws {
        let image = makeValidJpegData()
        let post = try OctopusPrefilledPost(images: [image])
        #expect(post.images == [image])
    }

    @Test func initAcceptsTenImages() throws {
        let images = (0..<10).map { _ in makeValidJpegData() }
        let post = try OctopusPrefilledPost(images: images)
        #expect(post.images.count == 10)
    }

    @Test func initThrowsTooManyImagesAtEleven() {
        let images = (0..<11).map { _ in makeValidJpegData() }
        #expect(throws: OctopusPrefilledPost.TooManyImagesError(max: 10, count: 11)) {
            _ = try OctopusPrefilledPost(images: images)
        }
    }

    @Test func tooManyImagesCountsOnlyNonEmptyEntries() throws {
        // 10 real images plus empty entries: the empty ones are dropped before the count check.
        let images = (0..<10).map { _ in makeValidJpegData() } + [Data(), Data()]
        let post = try OctopusPrefilledPost(images: images)
        #expect(post.images.count == 10)
    }

    @Test func tooManyImagesDebugDescriptionIsExplicit() {
        let error = OctopusPrefilledPost.TooManyImagesError(max: 10, count: 11)
        #expect(error.debugDescription ==
                "OctopusPrefilledPost.TooManyImagesError: 11 images provided, at most 10 are accepted.")
    }

    @Test func emptyImageDataIsDropped() throws {
        let valid = makeValidJpegData()
        let post = try OctopusPrefilledPost(images: [Data(), valid])
        #expect(post.images.count == 1)
        #expect(post.images == [valid])
    }

    @Test func secondInvalidImageThrows() {
        let valid = makeValidJpegData()
        #expect(throws: OctopusPrefilledPost.ValidationError.imageInvalid) {
            _ = try OctopusPrefilledPost(images: [valid, Data([0xFF])])
        }
    }

    @Test func imagesKeepTheirOrder() throws {
        let first = makeJpegData(width: 200, height: 200)
        let second = makeJpegData(width: 300, height: 200)
        let post = try OctopusPrefilledPost(images: [first, second])
        #expect(post.images == [first, second])
    }

    @Test func initAcceptsAllFields() throws {
        let post = try OctopusPrefilledPost(
            text: "hello world long enough",
            images: [makeValidJpegData()],
            topicId: "topic-id",
            cta: try OctopusPrefilledPost.CTA(
                url: URL(string: "myapp://item/42")!, label: "Open"))
        #expect(post.topicId == "topic-id")
        #expect(post.cta?.label == "Open")
    }

    // MARK: - bridge share token provider

    @Test func initForwardsSignToTheTokenProvider() async throws {
        let post = try OctopusPrefilledPost(sign: { "jwt-for-\($0)" })
        #expect(try await post.bridgeShareTokenProvider?("fingerprint") == "jwt-for-fingerprint")
    }

    @Test func tokenProviderCanDeclineToSign() async throws {
        let post = try OctopusPrefilledPost(sign: { _ in nil })
        let provider = try #require(post.bridgeShareTokenProvider)
        #expect(try await provider("fingerprint") == nil)
    }

    @Test func noTokenProviderWithoutSign() throws {
        #expect(try OctopusPrefilledPost().bridgeShareTokenProvider == nil)
    }

    // MARK: - test helpers

    fileprivate func makeValidJpegData() -> Data {
        makeJpegData(width: 200, height: 200)
    }

    fileprivate func makeJpegData(width: CGFloat, height: CGFloat) -> Data {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image.jpegData(compressionQuality: 0.8)!
    }
}

/// Deprecated APIs (tests are still here to ensure old APIs can still be called)
extension OctopusPrefilledPostTests {
    @Test func deprecatedImageReturnsFirst() throws {
        let first = makeJpegData(width: 200, height: 200)
        let second = makeJpegData(width: 300, height: 200)
        let post = try OctopusPrefilledPost(images: [first, second])
        #expect(post.image == first)
    }

    @Test func deprecatedImageIsNilWithoutImages() throws {
        let post = try OctopusPrefilledPost(text: "hello world long enough")
        #expect(post.image == nil)
    }

    @Test func deprecatedImageInitForwardsToImages() throws {
        let image = makeValidJpegData()
        let post = try OctopusPrefilledPost(text: nil, image: image, topicId: "topic-id", cta: nil)
        #expect(post.images == [image])
        #expect(post.topicId == "topic-id")
    }

    @Test func deprecatedImageInitWithNilOrEmptyImageHasNoImages() throws {
        #expect(try OctopusPrefilledPost(image: nil).images.isEmpty)
        #expect(try OctopusPrefilledPost(image: Data()).images.isEmpty)
    }

    @Test func deprecatedImageInitForwardsSignToTheTokenProvider() async throws {
        let post = try OctopusPrefilledPost(text: nil, image: nil, sign: { "jwt-for-\($0)" })
        #expect(try await post.bridgeShareTokenProvider?("fingerprint") == "jwt-for-fingerprint")
    }

    @Test func deprecatedSignReturnsTheToken() async throws {
        let sign = try #require(try OctopusPrefilledPost(sign: { "jwt-for-\($0)" }).sign)
        #expect(try await sign("fingerprint") == "jwt-for-fingerprint")
    }

    @Test func deprecatedSignThrowsWhenTheProviderDeclines() async throws {
        let sign = try #require(try OctopusPrefilledPost(sign: { _ in nil }).sign)
        await #expect(throws: (any Error).self) { try await sign("fingerprint") }
    }

    @Test func deprecatedSignIsNilWithoutTokenProvider() throws {
        #expect(try OctopusPrefilledPost().sign == nil)
    }

    @Test func deprecatedImageInitStillValidates() {
        #expect(throws: OctopusPrefilledPost.ValidationError.imageInvalid) {
            _ = try OctopusPrefilledPost(image: Data([0xFF, 0xD8]))
        }
    }
}
