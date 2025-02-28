//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public struct Post: Equatable, Sendable {
    public let uuid: String
    public let headline: String
    public let text: String?
    public let medias: [Media]
    public let author: MinimalProfile?
    public let creationDate: Date
    public let updateDate: Date
    public let parentId: String
    public let newestFirstCommentsFeed: Feed<Comment>?
    public let oldestFirstCommentsFeed: Feed<Comment>?

    public let aggregatedInfo: AggregatedInfo
    public let userInteractions: UserInteractions

    let innerStatus: StorableStatus
    let innerStatusReasons: [StorableStatusReason]

    public var status: Status {
        Status(status: innerStatus, reasons: innerStatusReasons)
    }

    public var canBeDisplayed: Bool {
        switch status {
        case .published, .other: return true
        case .moderated: return false
        }
    }
}

extension Post {
    init(storablePost: StorablePost, commentFeedsStore: CommentFeedsStore) {
        uuid = storablePost.uuid
        headline = storablePost.headline
        text = storablePost.text
        medias = storablePost.medias
        author = storablePost.author
        creationDate = storablePost.creationDate
        updateDate = storablePost.updateDate
        innerStatus = storablePost.status
        innerStatusReasons = storablePost.statusReasons
        parentId = storablePost.parentId
        if let descCommentFeedId = storablePost.descCommentFeedId {
            newestFirstCommentsFeed = commentFeedsStore.getOrCreate(feedId: descCommentFeedId)
        } else {
            newestFirstCommentsFeed = nil
        }
        if let ascCommentFeedId = storablePost.ascCommentFeedId {
            oldestFirstCommentsFeed = commentFeedsStore.getOrCreate(feedId: ascCommentFeedId)
        } else {
            oldestFirstCommentsFeed = nil
        }

        aggregatedInfo = storablePost.aggregatedInfo ?? .empty
        userInteractions = UserInteractions(userLikeId: storablePost.userLikeId)
    }
}
