//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct UserInteractions: Equatable, Sendable {
    public static let empty = UserInteractions(reaction: nil, pollVoteId: nil)
    static let temporaryReactionId = "tmpReactionId"

    public let reaction: UserReaction?
    public let pollVoteId: String?

    public var hasVoted: Bool {
        pollVoteId != nil
    }
}

extension UserInteractions {
    init(from entity: OctoObjectEntity) {
        if let reactionKind = entity.userReactionKind, let reactionId = entity.userReactionId {
            reaction = UserReaction(kind: .init(unicode: reactionKind), id: reactionId)
        } else {
            reaction = nil
        }
        pollVoteId = entity.userPollVoteId
    }

    init(from requesterCtx: Com_Octopuscommunity_RequesterCtx) {
        reaction = requesterCtx.hasReactionCtx ? UserReaction(from: requesterCtx.reactionCtx) : nil
        pollVoteId = requesterCtx.hasPollAnswerID ? requesterCtx.pollAnswerID.nilIfEmpty : nil
    }
}
