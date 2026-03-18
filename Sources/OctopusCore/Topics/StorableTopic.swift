//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct StorableTopic: Equatable, Sendable {
    let uuid: String
    let name: String
    let description: String
    let followStatus: StorableFollowStatus
    let sections: [StorableSection]
    let feedId: String
}

extension StorableTopic {
    init(from entity: TopicEntity) {
        uuid = entity.uuid
        name = entity.name
        description = entity.desc
        followStatus = .init(rawValue: entity.followStatusValue)
        sections = entity.sections.map { StorableSection(from: $0) }
        feedId = entity.descChildrenFeedId ?? ""
    }

    init?(from octoTopic: Com_Octopuscommunity_OctoObject, sections: [StorableSection]) {
        guard octoTopic.hasContent && octoTopic.content.hasTopic else { return nil }
        uuid = octoTopic.id
        name = octoTopic.content.topic.name
        description = octoTopic.content.topic.description_p
        followStatus = .init(from: octoTopic.content.topic.followStatus)
        self.sections = octoTopic.content.topic.sectionIds.compactMap { sectionId in
            sections.first(where: { $0.uuid == sectionId })
        }
        feedId = octoTopic.descChildrenFeedID
    }
}

extension Array where Element == StorableTopic {
    init(from octoTopics: [Com_Octopuscommunity_OctoObject], octoSections: [Com_Octopuscommunity_OctoObject]) {
        let sections = [StorableSection](from: octoSections)
        self = octoTopics.compactMap { StorableTopic(from: $0, sections: sections) }
    }
}

// Must be the same as `Com_Octopuscommunity_Topic.FollowStatus`
enum StorableFollowStatus: Equatable {
    case unknown
    case followed
    case notFollowed
    case forceFollowed
    case forceNotFollowed
    case UNRECOGNIZED(Int)

    init(rawValue: Int) {
        self = switch rawValue {
        case StorableFollowStatus.unknown.rawValue: .unknown
        case StorableFollowStatus.followed.rawValue: .followed
        case StorableFollowStatus.notFollowed.rawValue: .notFollowed
        case StorableFollowStatus.forceFollowed.rawValue: .forceFollowed
        case StorableFollowStatus.forceNotFollowed.rawValue: .forceNotFollowed
        default: .UNRECOGNIZED(rawValue)
        }
    }

    init(from octoStatus: Com_Octopuscommunity_Topic.FollowStatus) {
        self = switch octoStatus {
        case .unspecifiedFollowStatus: .unknown
        case .topicFollowed: .followed
        case .topicNotFollowed: .notFollowed
        case .topicForceFollowed: .forceFollowed
        case .topicForceNotFollowed: .forceNotFollowed
        case let .UNRECOGNIZED(rawValue):   .UNRECOGNIZED(rawValue)
        }
    }

    var rawValue: Int {
        switch self {
        case .unknown: Com_Octopuscommunity_Topic.FollowStatus.unspecifiedFollowStatus.rawValue
        case .followed: Com_Octopuscommunity_Topic.FollowStatus.topicFollowed.rawValue
        case .notFollowed: Com_Octopuscommunity_Topic.FollowStatus.topicNotFollowed.rawValue
        case .forceFollowed: Com_Octopuscommunity_Topic.FollowStatus.topicForceFollowed.rawValue
        case .forceNotFollowed: Com_Octopuscommunity_Topic.FollowStatus.topicForceNotFollowed.rawValue
        case .UNRECOGNIZED(let i): i
        }
    }
}
