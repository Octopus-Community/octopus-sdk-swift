//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

struct GroupCTAViewData: Equatable {
    let ctaText: TranslatableText
    let targetUrl: URL
}

struct GroupDetail {
    let id: String
    let name: String
    let description: EllipsizableText
    let feedId: String
    let canChangeFollowStatus: Bool
    let isFollowed: Bool
    let customAction: GroupCTAViewData?
    let coreTopic: OctopusCore.Topic
}

extension GroupDetail {
    /// - Parameter isListed: whether the groups list holds the group. A group outside it cannot be followed from
    ///   here: the follow would only be undone from that list, where the group does not appear.
    init(from topic: Topic, isListed: Bool = true) {
        id = topic.uuid
        name = topic.name
        description = EllipsizableText(text: topic.description, maxLength: 140, maxLines: 2)
        feedId = topic.feedId
        canChangeFollowStatus = topic.canChangeFollowStatus && isListed
        isFollowed = topic.isFollowed
        customAction = topic.customAction.map {
            GroupCTAViewData(ctaText: $0.ctaText, targetUrl: $0.targetUrl)
        }
        coreTopic = topic
    }
}
