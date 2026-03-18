//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

public struct Topic: Sendable, Equatable, Hashable {
    public let uuid: String
    public let name: String
    public let description: String
    public let canChangeFollowStatus: Bool
    public let isFollowed: Bool
    public let sections: [Section]
    public let feedId: String

    public let feed: Feed<Post, Comment>
}

extension Topic {
    init(from topic: StorableTopic, postFeedsStore: PostFeedsStore) {
        uuid = topic.uuid
        name = topic.name
        description = topic.description
        feedId = topic.feedId
        canChangeFollowStatus = switch topic.followStatus {
        case .followed, .notFollowed: true
        case .forceNotFollowed, .forceFollowed: false
        case .UNRECOGNIZED, .unknown: false
        }
        isFollowed = switch topic.followStatus {
        case .followed, .forceFollowed: true
        case .notFollowed, .forceNotFollowed: false
        case .UNRECOGNIZED, .unknown: false
        }
        sections = topic.sections.map { .init(from: $0) }

        feed = postFeedsStore.getOrCreate(feedId: feedId)
    }
}
