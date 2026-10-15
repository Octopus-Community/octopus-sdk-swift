//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension PostDetailViewModel.Post {
    init(from post: Post,
         gamificationLevels: [GamificationLevel],
         thisUserProfileId: String?, topic: OctopusCore.Topic?,
         dateFormatter: RelativeDateTimeFormatter) {
        uuid = post.uuid
        text = post.text
        author = .init(
            profile: post.author,
            gamificationLevel: gamificationLevels.first { $0.level == post.author?.gamificationLevel }
        )
        relativeDate = dateFormatter.localizedString(for: post.creationDate, relativeTo: Date())
        self.topic = topic?.name
        self.groupId = post.parentId
        attachments = PostAttachmentsViewData(from: post)
        canBeDeleted = post.author != nil && post.author?.uuid == thisUserProfileId
        canBeModerated = post.author?.uuid != thisUserProfileId
        canBeBlockedByUser = author.canBeBlocked(currentUserId: thisUserProfileId)
        canCreateChildren = post.permissions.canCreateChildren
        aggregatedInfo = post.aggregatedInfo
        userInteractions = post.userInteractions
        bridgeCTA = if let bridgeInfo = post.clientObjectBridgeInfo,
                       let ctaText = bridgeInfo.ctaText {
            BridgeCTA(text: ctaText, clientObjectId: bridgeInfo.objectId)
        } else {
            nil
        }
        customAction = if let customAction = post.customAction {
            CustomAction(ctaText: customAction.ctaText, targetUrl: customAction.targetUrl)
        } else {
            nil
        }
        catchPhrase = post.clientObjectBridgeInfo?.catchPhrase
    }

    var hasVideo: Bool { attachments.hasVideo }

    var videoId: String? { attachments.videoId }
}
