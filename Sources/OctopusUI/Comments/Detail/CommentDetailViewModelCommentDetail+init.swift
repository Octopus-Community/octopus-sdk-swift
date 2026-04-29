//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension CommentDetailViewModel.CommentDetail {
    init(from comment: Comment,
         gamificationLevels: [GamificationLevel],
         thisUserProfileId: String?, dateFormatter: RelativeDateTimeFormatter) {
        uuid = comment.uuid
        parentId = comment.parentId
        text = comment.text
        image = ImageMedia(from: comment.medias.first(where: { $0.kind == .image }))
        author = .init(
            profile: comment.author,
            gamificationLevel: gamificationLevels.first { $0.level == comment.author?.gamificationLevel }
        )
        relativeDate = dateFormatter.localizedString(for: comment.creationDate, relativeTo: Date())
        canBeDeleted = comment.author != nil && comment.author?.uuid == thisUserProfileId
        canBeModerated = comment.author?.uuid != thisUserProfileId
        canBeBlockedByUser = author.canBeBlocked(currentUserId: thisUserProfileId)
        aggregatedInfo = comment.aggregatedInfo
        userInteractions = comment.userInteractions
    }
}
