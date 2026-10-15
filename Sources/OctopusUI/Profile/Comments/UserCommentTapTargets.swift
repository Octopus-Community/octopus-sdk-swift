//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Where the taps of a profile Comments-tab cell lead. Pure so the destination is unit-tested apart from
/// the SwiftUI cell that wires it.
///
/// Both taps aim at the entry's top-level comment: the member's own comment, or the comment their reply
/// answers. Its card opens the post detail scrolled to it, the way a featured comment does in the feed,
/// and "See N (other) replies" opens its thread. The member's reply keeps opening that thread scrolled to
/// the reply.
struct UserCommentTapTargets: Equatable {
    /// The top-level comment the comment card scrolls the post to, and whose thread "See replies" opens.
    let topLevelCommentId: String

    /// - Parameters:
    ///   - commentId: the member's comment or reply.
    ///   - parentCommentId: for a reply, the comment it answers; `nil` for a comment.
    init(commentId: String, parentCommentId: String?) {
        topLevelCommentId = parentCommentId ?? commentId
    }
}
