//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct Media: Equatable, Sendable {
    public enum Kind: Sendable, Equatable {
        case image
        case video
    }

    public let url: URL
    public let thumbnailUrl: URL?
    public let kind: Kind
    public let size: CGSize
    public let videoId: String?
}

extension Media {
    init?(from entity: MediaEntity) {
        guard let entityKind = entity.kind else { return nil }
        url = entity.url
        kind = .init(from: entityKind)
        size = entity.size
        thumbnailUrl = entity.thumbnailUrl
        videoId = entity.videoId
    }

    init?(from image: Com_Octopuscommunity_Image) {
        guard let url = URL(string: image.url) else { return nil }
        kind = .image
        self.url = url
        size = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        thumbnailUrl = nil
        videoId = nil
    }

    init?(from media: Com_Octopuscommunity_MediaContent) {
        guard media.hasData else { return nil }
        guard case let .videoData(video) = media.data.data else { return nil }
        guard let url = URL(string: video.url) else { return nil }
        kind = .video
        self.url = url
        size = CGSize(width: CGFloat(video.width), height: CGFloat(video.height))
        thumbnailUrl = video.hasThumbnailURL ? URL(string: video.thumbnailURL) : nil
        self.videoId = media.id
    }
}

extension Media.Kind {
    init(from entity: MediaEntity.Kind) {
        switch entity {
        case .image: self = .image
        case .video: self = .video
        }
    }

    var entity: MediaEntity.Kind {
        switch self {
        case .image: return .image
        case .video: return .video
        }
    }
}
