//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(OctoObjectEntity)
class OctoObjectEntity: NSManagedObject, Identifiable {
    @NSManaged public var authorId: String?
    @NSManaged public var authorNickname: String?
    @NSManaged public var authorAvatarUrl: URL?
    @NSManaged public var creationTimestamp: Double
    @NSManaged public var updateTimestamp: Double
    @NSManaged public var statusValue: Int16
    @NSManaged public var statusReasonCodes: String
    @NSManaged public var statusReasonMessages: String
    @NSManaged public var parentId: String
    @NSManaged public var uuid: String

    @NSManaged public var likeCount: Int
    @NSManaged public var childCount: Int
    @NSManaged public var viewCount: Int
    @NSManaged public var pollTotalVoteCount: Int
    @NSManaged public var userLikeId: String?
    @NSManaged public var userPollVoteId: String?

    @NSManaged public var descChildrenFeedId: String?
    @NSManaged public var ascChildrenFeedId: String?

    @NSManaged public var pollOptionResultsRelationship: NSOrderedSet?

    var pollResults: [PollOptionResultEntity]? {
        guard let pollOptions = pollOptionResultsRelationship?.array as? [PollOptionResultEntity] else {
            return nil
        }
        return pollOptions
    }

    func fill(with content: StorableContent, context: NSManagedObjectContext) {
        uuid = content.uuid
        authorId = content.author?.uuid
        authorNickname = content.author?.nickname
        authorAvatarUrl = content.author?.avatarUrl
        creationTimestamp = content.creationDate.timeIntervalSince1970
        updateTimestamp = content.updateDate.timeIntervalSince1970
        statusValue = content.status.rawValue
        statusReasonCodes = content.statusReasons.storableCodes
        statusReasonMessages = content.statusReasons.storableMessages
        parentId = content.parentId

        viewCount = content.aggregatedInfo.viewCount
        fill(aggregatedInfo: content.aggregatedInfo, userInteractions: content.userInteractions, context: context)
    }

    func fill(aggregatedInfo: AggregatedInfo?, userInteractions: UserInteractions?, context: NSManagedObjectContext) {
        if let aggregatedInfo {
            viewCount = aggregatedInfo.viewCount
            if userInteractions?.userLikeId != nil {
                likeCount = max(aggregatedInfo.likeCount, 1)
            } else {
                likeCount = aggregatedInfo.likeCount
            }
            childCount = aggregatedInfo.childCount
            if let pollResult = aggregatedInfo.pollResult {
                pollTotalVoteCount = pollResult.totalVoteCount
                pollOptionResultsRelationship = NSOrderedSet(array: pollResult.votes.map {
                    let pollOptionResultEntity = PollOptionResultEntity(context: context)
                    pollOptionResultEntity.optionId = $0.optionId
                    pollOptionResultEntity.voteCount = $0.voteCount
                    return pollOptionResultEntity
                })
            } else {
                pollTotalVoteCount = 0
                pollOptionResultsRelationship = nil
            }
        }

        if let userInteractions {
            userLikeId = userInteractions.userLikeId
            userPollVoteId = userInteractions.pollVoteId
        }
    }
}
