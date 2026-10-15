//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI
@testable import OctopusCore

@Suite
struct PostAttachmentsViewDataTests {
    private let imageMedia = OctopusCore.Media(
        url: URL(string: "https://example.com/i.jpg")!, thumbnailUrl: nil,
        kind: .image, size: CGSize(width: 700, height: 750), videoId: nil)
    private let videoMedia = OctopusCore.Media(
        url: URL(string: "https://example.com/v.mp4")!, thumbnailUrl: nil,
        kind: .video, size: CGSize(width: 1920, height: 1080), videoId: "video-1")
    private let poll = Poll(options: [
        .init(id: "1", text: TranslatableText(originalText: "Red", originalLanguage: nil)),
        .init(id: "2", text: TranslatableText(originalText: "Blue", originalLanguage: nil))
    ])

    private var expectedImage: PostAttachmentsViewData.Media {
        .image(ImageMedia(url: URL(string: "https://example.com/i.jpg")!, size: CGSize(width: 700, height: 750)))
    }

    @Test func imageAndPollAreBothKept() {
        let attachments = PostAttachmentsViewData(medias: [imageMedia], poll: poll)
        #expect(attachments.media == expectedImage)
        #expect(attachments.poll?.options.map(\.id) == ["1", "2"])
    }

    @Test func pollOnly() {
        let attachments = PostAttachmentsViewData(medias: [], poll: poll)
        #expect(attachments.media == nil)
        #expect(attachments.poll?.options.map(\.id) == ["1", "2"])
    }

    @Test func imageOnly() {
        let attachments = PostAttachmentsViewData(medias: [imageMedia], poll: nil)
        #expect(attachments.media == expectedImage)
        #expect(attachments.poll == nil)
        #expect(!attachments.hasVideo)
    }

    @Test func videoOnly() {
        let attachments = PostAttachmentsViewData(medias: [videoMedia], poll: nil)
        #expect(attachments.hasVideo)
        #expect(attachments.videoId == "video-1")
        #expect(attachments.poll == nil)
    }

    @Test func videoAndPollAreBothKept() {
        // The backend refuses this combination; the display must still not lose a block.
        let attachments = PostAttachmentsViewData(medias: [videoMedia], poll: poll)
        #expect(attachments.videoId == "video-1")
        #expect(attachments.poll?.options.map(\.id) == ["1", "2"])
    }

    @Test func nothingAttached() {
        #expect(PostAttachmentsViewData(medias: [], poll: nil) == .empty)
    }

    @Test func videoWinsOverImage() {
        let attachments = PostAttachmentsViewData(medias: [imageMedia, videoMedia], poll: nil)
        #expect(attachments.videoId == "video-1")
    }

    @Test func videoWithoutIdFallsBackToImage() {
        let videoWithoutId = OctopusCore.Media(
            url: URL(string: "https://example.com/no-id.mp4")!, thumbnailUrl: nil,
            kind: .video, size: CGSize(width: 1920, height: 1080), videoId: nil)
        let attachments = PostAttachmentsViewData(medias: [videoWithoutId, imageMedia], poll: nil)
        #expect(attachments.media == expectedImage)
        #expect(!attachments.hasVideo)
    }
}
