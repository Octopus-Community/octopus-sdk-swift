//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

struct GroupList {
    struct Group {
        let id: String
        let name: String
        let feedId: String
        let coreTopic: OctopusCore.Topic
    }

    enum Section: Hashable {
        case followedGroups
        case otherGroups
        case clientSection(name: String)
    }

    let sections: [Section]
    let groupsBySection: [Section: [Group]]
}

extension GroupList {
    init(from topics: [OctopusCore.Topic]) {
        var sections: [Section] = []
        var groups: [GroupList.Section: [GroupList.Group]] = [:]

        let followedTopics = topics
            .filter { $0.isFollowed }
            .sorted {
                switch ($0.canChangeFollowStatus, $1.canChangeFollowStatus) {
                case (false, true): true
                case (true, false): false
                default: false

                }
            }
        if !followedTopics.isEmpty {
            sections.append(.followedGroups)
            groups[.followedGroups] = followedTopics.map { .init(from: $0) }
        }

        let coreSections = Dictionary(
            // put all sections into an array, then create a dictionary indexed by section id
            topics.map { $0.sections }.flatMap { $0 }.map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first })
            // take values to only have uniques sections
            .values
            // sort them by position
            .sorted { $0.position < $1.position }
        for coreSection in coreSections {
            let topicsOfThisSection = topics.filter { $0.sections.contains(coreSection) }
            if !topicsOfThisSection.isEmpty {
                let section = Section.clientSection(name: coreSection.name)
                sections.append(section)
                groups[section] = topicsOfThisSection.map { .init(from: $0) }
            }
        }

        let otherTopics = topics.filter { !$0.isFollowed && $0.sections.isEmpty }
        if !otherTopics.isEmpty {
            sections.append(.otherGroups)
            groups[.otherGroups] = otherTopics.map { .init(from: $0) }
        }

        self.groupsBySection = groups
        self.sections = sections
    }
}

extension GroupList.Group {
    init(from topic: Topic) {
        id = topic.uuid
        name = topic.name
        feedId = topic.feedId
        coreTopic = topic
    }
}
