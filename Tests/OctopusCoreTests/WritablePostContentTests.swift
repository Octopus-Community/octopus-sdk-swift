//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct WritablePostContentTests {
    private let imageData = Data([0x01, 0x02, 0x03])
    private let poll = WritablePoll(options: [.init(text: "Red"), .init(text: "Blue")])

    @Test func rwOctoObjectCarriesImageAndPollTogether() {
        let post = WritablePost(topicId: "topic-id", text: "Which one?", images: [imageData], poll: poll)
        let proto = post.rwOctoObject(uploadIds: ["upload-id"], imagesAreOptimized: [true]).content.post
        #expect(proto.hasMedia)
        #expect(proto.media.images.count == 1)
        #expect(proto.media.images.first?.file == .uploadID("upload-id"))
        #expect(proto.media.images.first?.isOptimized == true)
        #expect(proto.hasPoll)
        #expect(proto.poll.answers.map(\.text) == ["Red", "Blue"])
    }

    @Test func rwOctoObjectWithImageOnlyHasNoPoll() {
        let post = WritablePost(topicId: "topic-id", text: "Look at this", images: [imageData])
        let proto = post.rwOctoObject(uploadIds: ["upload-id"], imagesAreOptimized: [true]).content.post
        #expect(proto.media.images.count == 1)
        #expect(!proto.hasPoll)
    }

    @Test func rwOctoObjectWithPollOnlyHasNoMedia() {
        let post = WritablePost(topicId: "topic-id", text: "Which one?", poll: poll)
        let proto = post.rwOctoObject(uploadIds: [], imagesAreOptimized: []).content.post
        #expect(!proto.hasMedia)
        #expect(proto.poll.answers.count == 2)
    }

    @Test func rwOctoObjectWithoutAttachmentHasNeitherMediaNorPoll() {
        let post = WritablePost(topicId: "topic-id", text: "Just some text")
        let proto = post.rwOctoObject(uploadIds: [], imagesAreOptimized: []).content.post
        #expect(!proto.hasMedia)
        #expect(!proto.hasPoll)
    }
}
