//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct BoundedPayload<Item: Equatable>: Equatable {
    var item: Item
    var bounds: Anchor<CGRect>
}

struct ItemVisibility<Item: Equatable> {
    let containerBounds: CGRect
    let bounds: CGRect
    let item: Item

    var isPartiallyVisible: Bool {
        containerBounds.intersects(bounds)
    }

    var topIsVisible: Bool {
        isPartiallyVisible && containerBounds.minY <= bounds.minY
    }

    var bottomIsVisible: Bool {
        isPartiallyVisible && containerBounds.maxY >= bounds.maxY
    }

    var isFullyVisible: Bool {
        isPartiallyVisible &&
        ((topIsVisible && bottomIsVisible) ||
         (containerBounds.height <= bounds.height))
    }

    var centerProximity: CGFloat {
        let midY = containerBounds.midY
        let itemMidY = bounds.midY
        return abs(midY - itemMidY) / bounds.height
    }
}

struct VisibleItemsPreference<Item: Equatable>: PreferenceKey {
    static var defaultValue: [BoundedPayload<Item>] { get { [] } }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

struct VisiblePost: Equatable {
    let uuid: String
    let videoId: String?
    let position: Int
    let hasVideo: Bool
    let isLast: Bool
}

extension DisplayablePost {
    var toVisiblePost: VisiblePost {
        VisiblePost(uuid: uuid, videoId: videoId, position: position, hasVideo: hasVideo, isLast: isLast)
    }
}
extension PostDetailViewModel.Post {
    var toVisiblePost: VisiblePost {
        // position is always 0 for the detail since there is one post
        VisiblePost(uuid: uuid, videoId: videoId, position: 0, hasVideo: hasVideo, isLast: false)
    }
}
