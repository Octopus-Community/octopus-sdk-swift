//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// What a post displays besides its text, shared by the feed and the post detail.
///
/// A post can carry a media and a poll together, so both are kept: the view decides where the media
/// goes depending on whether a poll is present. Images next to a poll are a normal combination; a
/// video next to a poll is not expected from the backend but is still kept rather than dropped.
struct PostAttachmentsViewData: Equatable {
    enum Media: Equatable {
        /// Never empty; keeps the order given by the backend.
        case images([ImageMedia])
        case video(VideoMedia)
    }

    let media: Media?
    let poll: DisplayablePoll?

    static let empty = PostAttachmentsViewData(media: nil, poll: nil)

    static func images(_ images: [ImageMedia]) -> PostAttachmentsViewData {
        PostAttachmentsViewData(media: .images(images), poll: nil)
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

    /// A post never carries a video and images together; the video is looked up first, and only the first
    /// one is considered. A video without an id is skipped. Without a video, every image is kept, in order.
    private static func displayedMedia(in medias: [OctopusCore.Media]) -> Media? {
        if let video = VideoMedia(from: medias.first(where: { $0.kind == .video })) {
            return .video(video)
        }
        let images = medias.compactMap { ImageMedia(from: $0) }
        return images.isEmpty ? nil : .images(images)
    }
}
