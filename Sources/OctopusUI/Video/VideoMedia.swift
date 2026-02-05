//
//  Copyright © 2026 Octopus Community. All rights reserved.
//


import Foundation
import OctopusCore

struct VideoMedia: Equatable {
    let videoId: String
    let url: URL
    let size: CGSize
    let thumbnailUrl: URL?

    init?(from media: Media?) {
        guard let media, let videoId = media.videoId, media.kind == .video else { return nil }
        self.videoId = videoId
        url = media.url
        size = media.size
        thumbnailUrl = media.thumbnailUrl
    }

    init(videoId: String, url: URL, size: CGSize, thumbnailUrl: URL? = nil) {
        self.videoId = videoId
        self.url = url
        self.size = size
        self.thumbnailUrl = thumbnailUrl
    }
}
