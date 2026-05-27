//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import UIKit
import Octopus

struct OctopusPrefilledPostTests {

    // MARK: - content-empty

    @Test func initThrowsContentEmptyWhenBothNil() {
        #expect(throws: OctopusPrefilledPost.ValidationError.contentEmpty) {
            _ = try OctopusPrefilledPost(text: nil, image: nil)
        }
    }

    @Test func initThrowsContentEmptyWhenBothEmpty() {
        #expect(throws: OctopusPrefilledPost.ValidationError.contentEmpty) {
            _ = try OctopusPrefilledPost(text: "", image: Data())
        }
    }

    // MARK: - text validation

    @Test func initThrowsTextTooShort() {
        #expect(throws: OctopusPrefilledPost.ValidationError.self) {
            _ = try OctopusPrefilledPost(text: "hi")
        }
    }

    @Test func initThrowsTextTooShortEvenWithImage() throws {
        let image = makeValidJpegData()
        #expect(throws: OctopusPrefilledPost.ValidationError.self) {
            _ = try OctopusPrefilledPost(text: "hi", image: image)
        }
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
            _ = try OctopusPrefilledPost(image: bogus)
        }
    }

    @Test func initThrowsImageTooSmall() {
        // Validators.Picture.minSize is 50. A 10×10 image has minSide < 50 → .sideTooSmall.
        let smallImage = makeJpegData(width: 10, height: 10)
        #expect(throws: OctopusPrefilledPost.ValidationError.self) {
            _ = try OctopusPrefilledPost(image: smallImage)
        }
    }

    @Test func initThrowsImageRatioTooLarge() {
        // Validators.Picture.maxRatio is 32/9 (≈3.56). 60×400 has ratio ~6.67 → .ratioTooBig.
        let skinnyImage = makeJpegData(width: 60, height: 400)
        #expect(throws: OctopusPrefilledPost.ValidationError.self) {
            _ = try OctopusPrefilledPost(image: skinnyImage)
        }
    }

    // MARK: - CTA validation

    @Test func ctaInitThrowsOnEmptyLabel() {
        #expect(throws: OctopusPrefilledPost.ValidationError.ctaLabelEmpty) {
            _ = try OctopusPrefilledPost.CTA(url: URL(string: "https://example.com")!, label: "  ")
        }
    }

    // MARK: - happy path

    @Test func initAcceptsTextOnly() throws {
        let post = try OctopusPrefilledPost(text: "hello world long enough")
        #expect(post.text == "hello world long enough")
        #expect(post.image == nil)
        #expect(post.topicId == nil)
        #expect(post.cta == nil)
    }

    @Test func initAcceptsImageOnly() throws {
        let image = makeValidJpegData()
        let post = try OctopusPrefilledPost(image: image)
        #expect(post.image == image)
    }

    @Test func initAcceptsAllFields() throws {
        let post = try OctopusPrefilledPost(
            text: "hello world long enough",
            image: makeValidJpegData(),
            topicId: "topic-id",
            cta: try OctopusPrefilledPost.CTA(
                url: URL(string: "myapp://item/42")!, label: "Open"))
        #expect(post.topicId == "topic-id")
        #expect(post.cta?.label == "Open")
    }

    // MARK: - test helpers

    private func makeValidJpegData() -> Data {
        makeJpegData(width: 200, height: 200)
    }

    private func makeJpegData(width: CGFloat, height: CGFloat) -> Data {
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image.jpegData(compressionQuality: 0.8)!
    }
}
