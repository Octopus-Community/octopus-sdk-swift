//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// What a post displays besides its text, shared by the feed and the post detail.
///
/// A post can carry a media and a poll together, so both are kept: the view decides where the media
/// goes depending on whether a poll is present. An image next to a poll is a normal combination; a
/// video next to a poll is not expected from the backend but is still kept rather than dropped.
struct PostAttachmentsViewData: Equatable {
    enum Media: Equatable {
        case image(ImageMedia)
        case video(VideoMedia)
    }

    let media: Media?
    let poll: DisplayablePoll?

    static let empty = PostAttachmentsViewData(media: nil, poll: nil)

    static func image(_ image: ImageMedia) -> PostAttachmentsViewData {
        PostAttachmentsViewData(media: .image(image), poll: nil)
    }

    static func poll(_ poll: DisplayablePoll) -> PostAttachmentsViewData {
        PostAttachmentsViewData(media: nil, poll: poll)
    }

    var hasVideo: Bool { videoId != nil }

    var videoId: String? {
        if case let .video(video) = media { return video.videoId }
        return nil
    }
}

extension PostAttachmentsViewData {
    init(from post: Post) {
        self.init(medias: post.medias, poll: post.poll)
    }

    init(medias: [OctopusCore.Media], poll: Poll?) {
        self.init(media: Self.displayedMedia(in: medias), poll: poll.map { DisplayablePoll(from: $0) })
    }

    /// Only one media is displayed. A post never carries a video and an image together; the video is
    /// looked up first. Only the first video or the first image is considered, and a video without an
    /// id is skipped.
    private static func displayedMedia(in medias: [OctopusCore.Media]) -> Media? {
        if let video = VideoMedia(from: medias.first(where: { $0.kind == .video })) {
            return .video(video)
        }
        if let image = ImageMedia(from: medias.first(where: { $0.kind == .image })) {
            return .image(image)
        }
        return nil
    }
}
