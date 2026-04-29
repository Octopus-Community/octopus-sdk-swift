//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct ReactionCount: Equatable, Hashable, Sendable {
    public let reactionKind: ReactionKind
    public let count: Int

    public var isEmpty: Bool { count == 0 } // swiftlint:disable:this empty_count

    /// Public constructor, only for SwiftUI previews
    public init(reactionKind: ReactionKind, count: Int) {
        self.reactionKind = reactionKind
        self.count = count
    }
}

extension ReactionCount {
    init?(from reactionData: Com_Octopuscommunity_ReactionData) {
        // swiftlint:disable:next empty_count
        guard reactionData.count > 0 else { return nil }
        self.reactionKind = .init(unicode: reactionData.unicode)
        self.count = Int(reactionData.count)
    }

    init?(from entity: ContentReactionEntity) {
        // swiftlint:disable:next empty_count
        guard entity.count > 0 else { return nil }
        self.reactionKind = .init(unicode: entity.reactionKind)
        self.count = entity.count
    }
}
