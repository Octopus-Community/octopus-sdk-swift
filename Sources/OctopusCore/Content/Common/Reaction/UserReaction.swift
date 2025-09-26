//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct UserReaction: Equatable, Sendable {
    public let kind: ReactionKind
    let id: String
}

extension UserReaction {
    init?(from reactionCtx: Com_Octopuscommunity_ReactionCtx) {
        guard let reactionID = reactionCtx.reactionID.nilIfEmpty,
        let reactionKind = reactionCtx.unicode.nilIfEmpty else {
            return nil
        }
        self.kind = .init(unicode: reactionKind)
        self.id = reactionID
    }
}
