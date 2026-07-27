//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public struct Topic: Sendable, Equatable {
    public let uuid: String
    public let name: String
    public let description: String
    public let canChangeFollowStatus: Bool
    public let isFollowed: Bool
    public let sections: [Section]
    public let feedId: String
    public let permissions: UserPermissions
    public let customAction: CustomAction?

    public let feed: Feed<Post, Comment>
}

extension Topic {
    /// Returns a copy of the topic with its `sections` replaced. Used by the debug section-override
    /// affordance (see `TopicsRepository.debugOverrideTopicSections`) so the sample can exercise the
    /// sectioned group-list rendering without a backend that serves client sections.
    func withSections(_ sections: [Section]) -> Topic {
        Topic(uuid: uuid, name: name, description: description, canChangeFollowStatus: canChangeFollowStatus,
              isFollowed: isFollowed, sections: sections, feedId: feedId, permissions: permissions,
              customAction: customAction, feed: feed)
    }

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
        permissions = topic.permissions

        customAction = CustomAction(
            ctaText: topic.customActionText,
            targetLink: topic.customActionTargetLink)

        feed = postFeedsStore.getOrCreate(feedId: feedId)
    }
}
