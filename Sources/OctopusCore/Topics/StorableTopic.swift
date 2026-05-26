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
    let permissions: UserPermissions
    let customActionText: TranslatableText?
    let customActionTargetLink: String?

    init(uuid: String,
         name: String,
         description: String,
         followStatus: StorableFollowStatus,
         sections: [StorableSection],
         feedId: String,
         permissions: UserPermissions = .default,
         customActionText: TranslatableText? = nil,
         customActionTargetLink: String? = nil) {
        self.uuid = uuid
        self.name = name
        self.description = description
        self.followStatus = followStatus
        self.sections = sections
        self.feedId = feedId
        self.permissions = permissions
        self.customActionText = customActionText
        self.customActionTargetLink = customActionTargetLink
    }
}

extension StorableTopic {
    init(from entity: TopicEntity) {
        uuid = entity.uuid
        name = entity.name
        description = entity.desc
        followStatus = .init(rawValue: entity.followStatusValue)
        sections = entity.sections.map { StorableSection(from: $0) }
        feedId = entity.descChildrenFeedId ?? ""
        permissions = UserPermissions(
            canAccess: entity.canAccess,
            canCreateChildren: entity.canCreateChildren
        )
        customActionText = TranslatableText(originalText: entity.customActionText,
                                            originalLanguage: nil,
                                            translatedText: entity.customActionTranslatedText)
        customActionTargetLink = entity.customActionTargetLink
    }

    init?(from octoTopic: Com_Octopuscommunity_OctoObject,
          requesterCtx: Com_Octopuscommunity_RequesterCtx?,
          sections: [StorableSection]) {
        guard octoTopic.hasContent && octoTopic.content.hasTopic else { return nil }
        uuid = octoTopic.id
        name = octoTopic.content.topic.name
        description = octoTopic.content.topic.description_p
        followStatus = .init(from: octoTopic.content.topic.followStatus)
        self.sections = octoTopic.content.topic.sectionIds.compactMap { sectionId in
            sections.first(where: { $0.uuid == sectionId })
        }
        feedId = octoTopic.descChildrenFeedID
        permissions = UserPermissions(from: requesterCtx)

        if octoTopic.content.topic.hasCta {
            let cta = octoTopic.content.topic.cta
            let trimmedText = cta.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty, !cta.targetLink.isEmpty {
                customActionText = TranslatableText(
                    originalText: trimmedText,
                    originalLanguage: nil,
                    translatedText: cta.hasTranslatedText ? cta.translatedText : nil)
                customActionTargetLink = cta.targetLink
            } else {
                customActionText = nil
                customActionTargetLink = nil
            }
        } else {
            customActionText = nil
            customActionTargetLink = nil
        }
    }
}

extension Array where Element == StorableTopic {
    init(from octoTopics: [Com_Octopuscommunity_OctoObject],
         requesterCtxs: [Com_Octopuscommunity_RequesterCtx],
         octoSections: [Com_Octopuscommunity_OctoObject]) {
        let sections = [StorableSection](from: octoSections)
        self = octoTopics.enumerated().compactMap { index, octoTopic in
            let ctx = requesterCtxs.indices.contains(index) ? requesterCtxs[index] : nil
            return StorableTopic(from: octoTopic, requesterCtx: ctx, sections: sections)
        }
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
