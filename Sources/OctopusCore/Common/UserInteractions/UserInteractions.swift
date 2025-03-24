//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct UserInteractions: Equatable, Sendable {
    public static let empty = UserInteractions(userLikeId: nil)
    static let temporaryLikeId = "tmpLikeId"

    let userLikeId: String?
    
    public var hasLiked: Bool {
        userLikeId != nil
    }
}

extension UserInteractions {
    init(from requesterCtx: Com_Octopuscommunity_RequesterCtx) {
        userLikeId = requesterCtx.hasLikeID ? requesterCtx.likeID.nilIfEmpty : nil
    }
}
