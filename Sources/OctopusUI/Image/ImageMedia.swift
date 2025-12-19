//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

struct ImageMedia: Equatable {
    let url: URL
    let size: CGSize

    init?(from media: Media?) {
        guard let media, media.kind == .image else { return nil }
        url = media.url
        size = media.size
    }

    init(url: URL, size: CGSize) {
        self.url = url
        self.size = size
    }
}
