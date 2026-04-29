//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore
import os

struct CommentDetailRepliesView: View {
    @Environment(\.octopusTheme) private var theme

    let replies: [DisplayableFeedResponse]
    let hasMoreData: Bool
    let hideLoader: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousReplies: () -> Void
    let displayProfile: (String) -> Void
    let deleteReply: (String) -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        ForEach(replies, id: \.uuid) { reply in
            HStack(alignment: .top, spacing: 0) {
                Spacer().frame(width: 32 + 12) // to be aligned with the comment's card
                ResponseFeedItemView(
                    response: reply,
                    zoomableImageInfo: $zoomableImageInfo,
                    displayResponseDetail: { _, _ in },
                    displayProfile: displayProfile,
                    deleteResponse: deleteReply,
                    blockAuthor: blockAuthor,
                    reactionTapped: reactionTapped,
                    displayContentModeration: displayContentModeration)
                .onAppear {
                    reply.displayEvents.onAppear()
                }
                .onDisappear {
                    reply.displayEvents.onDisappear()
                }
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
            HStack(alignment: .top, spacing: 0) {
                Spacer().frame(width: 40)
                Compat.ProgressView()
                    .frame(width: 100)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        if #available(iOS 14, *) { Logger.posts.trace("Loader appeared, loading previous items...") }
                        loadPreviousReplies()
                    }
            }
        }
    }
}
