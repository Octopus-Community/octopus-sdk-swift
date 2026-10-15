//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore
import Testing
@testable import OctopusUI

@Suite
struct PostSummaryAccessibilityTests {
    private let image = PostAttachmentsViewData.Media.image(
        ImageMedia(url: URL(string: "https://example.com/i.jpg")!, size: CGSize(width: 10, height: 10)))
    private let video = PostAttachmentsViewData.Media.video(
        VideoMedia(videoId: "v", url: URL(string: "https://example.com/v.mp4")!,
                   size: CGSize(width: 10, height: 10)))
    private let poll = DisplayablePoll(options: [
        .init(id: "1", text: .init(originalText: "Red", originalLanguage: nil))
    ])

    @Test func imageAndPollUsesTheImageTemplate() {
        let attachments = PostAttachmentsViewData(media: image, poll: poll)
        #expect(PostSummaryAccessibility.template(for: attachments, hasText: true) == .textAndImage)
    }

    @Test func imageWithTextUsesTheImageTemplate() {
        #expect(PostSummaryAccessibility.template(for: .init(media: image, poll: nil), hasText: true) == .textAndImage)
    }

    @Test func videoUsesTheVideoTemplate() {
        #expect(PostSummaryAccessibility.template(for: .init(media: video, poll: nil), hasText: true) == .textAndVideo)
    }

    @Test func pollOnlyUsesTheTextOnlyTemplate() {
        #expect(PostSummaryAccessibility.template(for: .poll(poll), hasText: true) == .textOnly)
    }

    @Test func imageWithoutTextNorPollUsesTheImageOnlyTemplate() {
        #expect(PostSummaryAccessibility.template(for: .init(media: image, poll: nil), hasText: false) == .imageOnly)
    }

    @Test func imageAndPollWithoutTextKeepsTheImageTemplate() {
        let attachments = PostAttachmentsViewData(media: image, poll: poll)
        #expect(PostSummaryAccessibility.template(for: attachments, hasText: false) == .textAndImage)
    }

    @Test func pollOptionsAreAppendedToTheText() {
        #expect(PostSummaryAccessibility.textToRead("Which one?", pollOptionsToRead: "1: Red, 2: Blue")
                == "Which one?, 1: Red, 2: Blue")
    }

    @Test func pollOptionsAreReadAloneWithoutText() {
        #expect(PostSummaryAccessibility.textToRead("", pollOptionsToRead: "1: Red, 2: Blue") == "1: Red, 2: Blue")
    }

    @Test func textIsUnchangedWithoutPoll() {
        #expect(PostSummaryAccessibility.textToRead("Hello", pollOptionsToRead: nil) == "Hello")
    }
}
