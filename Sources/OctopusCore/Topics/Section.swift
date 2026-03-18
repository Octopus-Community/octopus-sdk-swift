//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

public struct Section: Sendable, Equatable, Hashable {
    public let uuid: String
    public let name: String
    public let position: Int
}

extension Section {
    init(from section: StorableSection) {
        uuid = section.uuid
        name = section.name
        position = section.position
    }
}
