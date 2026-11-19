//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

struct WritablePostTests {
    @Test func imagesAreReferencedByUploadIdInOrder() {
        let post = WritablePost(topicId: "topic-id", text: "Hello", images: [Data([1]), Data([2])])

        let object = post.rwOctoObject(uploadIds: ["first", "second"], imagesAreOptimized: [true, false])

        let images = object.content.post.media.images
        #expect(images.map(\.file) == [.uploadID("first"), .uploadID("second")])
        #expect(images.map(\.isOptimized) == [true, false])
    }

    @Test func aMissingOptimizedFlagMeansNotOptimized() {
        let post = WritablePost(topicId: "topic-id", text: "Hello", images: [Data([1]), Data([2])])

        let object = post.rwOctoObject(uploadIds: ["first", "second"], imagesAreOptimized: [true])

        #expect(object.content.post.media.images.map(\.isOptimized) == [true, false])
    }

    @Test func noUploadIdEmitsNoMedia() {
        let post = WritablePost(topicId: "topic-id", text: "Hello", images: [])

        let object = post.rwOctoObject(uploadIds: [], imagesAreOptimized: [])

        #expect(!object.content.post.hasMedia)
    }

    @Test func validatorCountsImagesAsImage() {
        let post = WritablePost(topicId: "topic-id", text: "   ", images: [Data([1])])

        #expect(Validators.Post.validate(post: post, textRequired: false))
    }
}
