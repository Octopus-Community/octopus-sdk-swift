//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

struct GroupDetail {
    let id: String
    let name: String
    let description: EllipsizableText
    let feedId: String
    let canChangeFollowStatus: Bool
    let isFollowed: Bool
    let coreTopic: OctopusCore.Topic
}

extension GroupDetail {
    init(from topic: Topic) {
        id = topic.uuid
        name = topic.name
        description = EllipsizableText(text: topic.description, maxLength: 140, maxLines: 2)
        feedId = topic.feedId
        canChangeFollowStatus = topic.canChangeFollowStatus
        isFollowed = topic.isFollowed
        coreTopic = topic
    }
}
