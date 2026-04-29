//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension PostDetailViewModel.Post.Attachment {
    init?(from post: Post) {
        if let poll = post.poll {
            self = .poll(DisplayablePoll(from: poll))
        } else if let media = post.medias.first(where: { $0.kind == .video }),
                  let videoMedia = VideoMedia(from: media) {
            self = .video(videoMedia)
        } else if let media = post.medias.first(where: { $0.kind == .image }),
                  let imageMedia = ImageMedia(from: media) {
            self = .image(imageMedia)
        } else {
            return nil
        }
    }
}

extension PostDetailViewModel.Post {
    init(from post: Post,
         gamificationLevels: [GamificationLevel],
         thisUserProfileId: String?, topic: OctopusCore.Topic,
         dateFormatter: RelativeDateTimeFormatter) {
        uuid = post.uuid
        text = post.text
        author = .init(
            profile: post.author,
            gamificationLevel: gamificationLevels.first { $0.level == post.author?.gamificationLevel }
        )
        relativeDate = dateFormatter.localizedString(for: post.creationDate, relativeTo: Date())
        self.topic = topic.name
        attachment = .init(from: post)
        canBeDeleted = post.author != nil && post.author?.uuid == thisUserProfileId
        canBeModerated = post.author?.uuid != thisUserProfileId
        canBeBlockedByUser = author.canBeBlocked(currentUserId: thisUserProfileId)
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

    var hasVideo: Bool {
        switch attachment {
        case .video: return true
        default: return false
        }
    }

    var videoId: String? {
        switch attachment {
        case let .video(video): return video.videoId
        default: return nil
        }
    }
}
