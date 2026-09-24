//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// One entry of the "who reacted" list: a member, and the reaction they left.
///
/// Distinct from ``UserReaction``, which is the *current* user's reaction on a content and carries the
/// reaction id needed to delete it. This one describes someone else's reaction and is read-only.
public struct ProfileReaction: Equatable, Sendable {
    /// `nil` when the member has been deleted or banned. The reaction still exists and still counts, so
    /// the entry is kept and rendered as an anonymous one rather than dropped.
    public let profile: MinimalProfile?
    public let kind: ReactionKind

    /// Public constructor, only for SwiftUI previews
    public init(profile: MinimalProfile?, kind: ReactionKind) {
        self.profile = profile
        self.kind = kind
    }
}

extension ProfileReaction {
    init(from userReaction: Com_Octopuscommunity_GetReactionsPageResponse.UserReaction) {
        // The backend documents the profile as "empty when the user is deleted or banned", which can
        // mean either an absent message or a present-but-blank one: treat both as "no profile".
        if userReaction.hasProfile, userReaction.profile.profileID.nilIfEmpty != nil {
            profile = MinimalProfile(from: userReaction.profile)
        } else {
            profile = nil
        }
        kind = .init(unicode: userReaction.unicode)
    }
}

/// A page of the "who reacted" list.
public struct ReactionsPage: Equatable, Sendable {
    /// Most recent reaction first.
    public let reactions: [ProfileReaction]
    /// Cursor to pass back to fetch the following page. `nil` when the list is exhausted.
    public let nextCursor: String?

    /// Public constructor, only for SwiftUI previews
    public init(reactions: [ProfileReaction], nextCursor: String?) {
        self.reactions = reactions
        self.nextCursor = nextCursor
    }
}
