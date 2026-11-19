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
    /// Whether the replies are the most recent end of the thread: older ones then load from the top of the list.
    var listsMostRecentEnd = false
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousReplies: () -> Void
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    let deleteReply: (String) -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (ReportTarget) -> Void

    @State private var windowLaidOutStart = MostRecentWindowLaidOutStart()

    var body: some View {
        if listsMostRecentEnd && hasMoreData && !hideLoader && !replies.isEmpty {
            loader
                // The scroll view loads older replies while it is on screen.
                .tracksOnScreenPresence()
        }
        if let laidOutStart {
            // Older pages are lazy, the rest of the window is laid out at once (see `MostRecentWindow.laidOutStart`).
            ForEach(replies[..<laidOutStart], id: \.uuid, content: row)
            VStack(spacing: 0) {
                ForEach(replies[laidOutStart...], id: \.uuid, content: row)
            }
            // A lazy stack scrolls to its own children only, laid out or not: the scroll keeping the first reply of
            // the part in place, once older ones are inserted above it, reaches it through the part.
            .id(ResponseKind.reply.laidOutPartScrollAnchorId)
        } else {
            ForEach(replies, id: \.uuid, content: row)
        }
        if !listsMostRecentEnd && hasMoreData && !hideLoader {
            loader
                .onAppear {
                    if #available(iOS 14, *) { Logger.posts.trace("Loader appeared, loading previous items...") }
                    loadPreviousReplies()
                }
        }
    }

    /// Where the laid out part of the window starts in `replies`, or `nil` when they are not the most recent end.
    private var laidOutStart: Int? {
        guard listsMostRecentEnd else {
            windowLaidOutStart.reset()
            return nil
        }
        return windowLaidOutStart.part(in: replies.map(\.uuid), pagesNewer: false).lowerBound
    }

    private func row(_ reply: DisplayableFeedResponse) -> some View {
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
        // On the row itself: a lazy stack scrolls to its own children only, not to the views nested in a child it has
        // not laid out.
        .id(reply.kind.scrollAnchorId(for: reply.uuid))
        .modify {
            if #available(iOS 17.0, *) {
                $0.geometryGroup()
            } else {
                $0
            }
        }
        // The scroll view follows a newer one only while the newest is on screen.
        .tracksOnScreenPresence(as: .newestItem, when: listsMostRecentEnd && reply.uuid == replies.last?.uuid)
    }

    private var loader: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer().frame(width: 40)
            Compat.ProgressView()
                .frame(width: 100)
                .frame(maxWidth: .infinity)
        }
    }
}
