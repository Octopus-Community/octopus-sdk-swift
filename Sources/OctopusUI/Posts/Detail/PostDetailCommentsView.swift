//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore
import os

struct PostDetailCommentsView: View {
    @Environment(\.octopusTheme) private var theme

    let comments: [DisplayableFeedResponse]
    let hasMoreData: Bool
    let hideLoader: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousComments: () -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deleteComment: (String) -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        if !comments.isEmpty {
            ForEach(comments, id: \.uuid) { comment in
                ResponseFeedItemView(
                    response: comment,
                    zoomableImageInfo: $zoomableImageInfo,
                    displayResponseDetail: displayCommentDetail,
                    displayProfile: displayProfile, deleteResponse: deleteComment,
                    blockAuthor: blockAuthor,
                    reactionTapped: reactionTapped,
                    displayContentModeration: displayContentModeration)
                .onAppear {
                    comment.displayEvents.onAppear()
                }
                .onDisappear {
                    comment.displayEvents.onDisappear()
                }
                .modify {
                    if #available(iOS 17.0, *) {
                        $0.geometryGroup()
                    } else {
                        $0
                    }
                }
            }
            if hasMoreData && !hideLoader {
                Compat.ProgressView()
                    .frame(width: 100)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        if #available(iOS 14, *) { Logger.posts.trace("Loader appeared, loading previous items...") }
                        loadPreviousComments()
                    }
            }
        } else {
            Button(action: openCreateComment) {
                VStack {
                    Spacer().frame(height: 54)
                    Image(uiImage: theme.assets.icons.content.comment.emptyFeed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)
                        .accessibilityHidden(true)
                    Text("Post.Detail.NoComments", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(theme.colors.gray500)
            }.buttonStyle(.plain)
        }
    }
}
