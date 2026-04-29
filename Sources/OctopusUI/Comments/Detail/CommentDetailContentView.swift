//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct CommentDetailContentView: View {
    @Environment(\.octopusTheme) private var theme

    let comment: CommentDetailViewModel.CommentDetail
    let displayGoToParentButton: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayProfile: (String) -> Void
    let openCreateReply: () -> Void
    let deleteComment: () -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let displayContentModeration: (String) -> Void
    let displayParentPost: (String, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if displayGoToParentButton {
                Button(action: { displayParentPost(comment.parentId, comment.uuid) }) {
                    Text("Comment.SeeParent", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray900)
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .background(
                            Capsule()
                                .stroke(theme.colors.gray300, lineWidth: 1)
                        )
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                }
                .buttonStyle(.plain)
            }

            ResponseView(
                response: ResponseViewData(from: comment),
                context: .detail,
                zoomableImageInfo: $zoomableImageInfo,
                reactionTapped: reactionTapped,
                displayProfile: displayProfile,
                deleteResponse: deleteComment,
                blockAuthor: blockAuthor,
                openCreateReply: openCreateReply,
                openRepliesList: {},
                displayContentModeration: displayContentModeration)
        }
    }
}
