//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

public struct Media: Equatable, Sendable {
    public enum Kind: Sendable {
        case image
        case video
    }

    public let url: URL
    public let kind: Kind
    public let size: CGSize
}

extension Media {
    init?(from entity: MediaEntity) {
        guard let entityKind = entity.kind else { return nil }
        url = entity.url
        kind = .init(from: entityKind)
        size = entity.size
    }

    init?(from media: Com_Octopuscommunity_Media, kind: Media.Kind) {
        guard let url = URL(string: media.url) else { return nil }
        self.url = url
        size = CGSize(width: CGFloat(media.width), height: CGFloat(media.height))
        self.kind = kind
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
