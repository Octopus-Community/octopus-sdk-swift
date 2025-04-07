//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct UserInteractions: Equatable, Sendable {
    public static let empty = UserInteractions(userLikeId: nil, pollVoteId: nil)
    static let temporaryLikeId = "tmpLikeId"

    let userLikeId: String?
    public let pollVoteId: String?

    public var hasLiked: Bool {
        userLikeId != nil
    }

    public var hasVoted: Bool {
        pollVoteId != nil
    }
}

extension UserInteractions {
    init(from requesterCtx: Com_Octopuscommunity_RequesterCtx) {
        userLikeId = requesterCtx.hasLikeID ? requesterCtx.likeID.nilIfEmpty : nil
        pollVoteId = requesterCtx.hasPollAnswerID ? requesterCtx.pollAnswerID.nilIfEmpty : nil
    }
}
