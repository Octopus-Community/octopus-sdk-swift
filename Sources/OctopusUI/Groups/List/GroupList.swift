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
        let canAccess: Bool
        let coreTopic: OctopusCore.Topic
    }

    enum Section: Hashable {
        case noSectionGroups
        case clientSection(name: String)
    }

    let sections: [Section]
    let groupsBySection: [Section: [Group]]
}

extension GroupList {
    init(from topics: [OctopusCore.Topic]) {
        var sections: [Section] = []
        var groups: [Section: [Group]] = [:]

        let noSectionTopics = topics.filter { $0.sections.isEmpty }
        if !noSectionTopics.isEmpty {
            sections.append(.noSectionGroups)
            groups[.noSectionGroups] = noSectionTopics.map { .init(from: $0) }
        }

        let coreSections = Dictionary(
            topics.flatMap { $0.sections }.map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first })
            .values
            .sorted { $0.position < $1.position }

        for coreSection in coreSections {
            let topicsOfThisSection = topics.filter { $0.sections.contains(coreSection) }
            if !topicsOfThisSection.isEmpty {
                let section = Section.clientSection(name: coreSection.name)
                sections.append(section)
                groups[section] = topicsOfThisSection.map { .init(from: $0) }
            }
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
        canAccess = topic.permissions.canAccess
        coreTopic = topic
    }
}
