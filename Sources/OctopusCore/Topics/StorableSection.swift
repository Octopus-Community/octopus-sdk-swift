//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

struct StorableSection: Equatable, Sendable {
    let uuid: String
    let name: String
    let position: Int
}

extension StorableSection {
    init(from entity: SectionEntity) {
        uuid = entity.uuid
        name = entity.name
        position = entity.position
    }

    init?(from octoSection: Com_Octopuscommunity_OctoObject, position: Int) {
        guard octoSection.hasContent && octoSection.content.hasSection else { return nil }
        uuid = octoSection.id
        name = octoSection.content.section.label
        self.position = position
    }
}

extension Array where Element == StorableSection {
    init(from octoSections: [Com_Octopuscommunity_OctoObject]) {
        self = octoSections.enumerated().compactMap { StorableSection(from: $1, position: $0) }
    }
}
