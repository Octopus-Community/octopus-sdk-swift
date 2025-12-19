//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct ReactionCount: Equatable, Hashable, Sendable {
    public let reactionKind: ReactionKind
    public let count: Int

    /// Public constructor, only for SwiftUI previews
    public init(reactionKind: ReactionKind, count: Int) {
        self.reactionKind = reactionKind
        self.count = count
    }
}

extension ReactionCount {
    init?(from reactionData: Com_Octopuscommunity_ReactionData) {
        guard reactionData.count > 0 else { return nil }
        self.reactionKind = .init(unicode: reactionData.unicode)
        self.count = Int(reactionData.count)
    }

    init?(from entity: ContentReactionEntity) {
        guard entity.count > 0 else { return nil }
        self.reactionKind = .init(unicode: entity.reactionKind)
        self.count = entity.count
    }
}
