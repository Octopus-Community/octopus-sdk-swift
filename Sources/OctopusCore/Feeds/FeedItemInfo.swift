//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct FeedItemInfo {
    let feedId: String
    let itemId: String
    let updateDate: Date
}

extension FeedItemInfo {
    init(from feedItemInfo: FeedItemInfoEntity) {
        self.feedId = feedItemInfo.feedId
        self.itemId = feedItemInfo.itemId
        self.updateDate = Date(timeIntervalSince1970: Double(feedItemInfo.updateTimestamp))
    }

    init(from feedItemInfo: Com_Octopuscommunity_FeedItemInfo, feedId: String) {
        self.feedId = feedId
        self.itemId = feedItemInfo.octoObjectID
        self.updateDate = Date(timestampMs: feedItemInfo.octoObjectUpdatedAt)
    }
}
