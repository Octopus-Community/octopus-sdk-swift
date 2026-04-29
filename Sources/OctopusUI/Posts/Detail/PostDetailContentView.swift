//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostDetailContentView: View {
    let post: PostDetailViewModel.Post
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let voteOnPoll: (String) -> Bool
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    var body: some View {
        PostView(
            post: PostViewData(from: post),
            context: .detail,
            width: width,
            zoomableImageInfo: $zoomableImageInfo,
            reactionTapped: reactionTapped,
            voteOnPoll: voteOnPoll,
            displayProfile: displayProfile,
            deletePost: deletePost,
            blockAuthor: blockAuthor,
            displayContentModeration: displayContentModeration,
            displayClientObject: displayClientObject,
            openCreateComment: openCreateComment)
    }
}
