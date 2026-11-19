//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostDetailContentView: View {
    let post: PostDetailViewModel.Post
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let voteOnPoll: (String) async -> Bool
    let displayContentModeration: (ReportTarget) -> Void
    let displayClientObject: ((String) -> Void)?
    /// Opens the post's group from its group name, when the community makes the group name open the group.
    var openGroup: (String) -> Void = { _ in }

    var body: some View {
        PostView(
            post: PostViewData(from: post),
            context: .detail,
            width: width,
            zoomableImageInfo: $zoomableImageInfo,
            reactionTapped: reactionTapped,
            voteOnPoll: voteOnPoll,
            displayProfile: displayProfile,
            // Detail renders its own nav-bar "…" menu (incl. "View group"); the in-header menu is
            // suppressed in `.detail` context. This closure only serves the group name, when the community
            // makes it open the group.
            openGroup: openGroup,
            deletePost: deletePost,
            blockAuthor: blockAuthor,
            displayContentModeration: displayContentModeration,
            displayClientObject: displayClientObject,
            openCreateComment: openCreateComment)
    }
}
