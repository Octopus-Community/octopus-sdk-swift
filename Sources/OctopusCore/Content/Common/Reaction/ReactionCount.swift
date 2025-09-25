//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct ReactionCount: Equatable, Hashable, Sendable {
    public let reaction: ReactionKind
    public let count: Int
}

extension ReactionCount {
    init(from reactionData: Com_Octopuscommunity_ReactionData) {
        self.reaction = .init(unicode: reactionData.unicode)
        self.count = Int(reactionData.count)
    }

    init(from entity: ContentReactionEntity) {
        self.reaction = .init(unicode: entity.reactionKind)
        self.count = entity.count
    }
}
