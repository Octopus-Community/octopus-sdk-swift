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
    /// Whether the comments are the most recent end of the thread: older ones then load from the top of the list.
    var listsMostRecentEnd = false
    /// Whether newer comments are still to load below the window the screen opened on.
    var hasNewerData = false
    /// The window of the thread the comments come from, when they are one (see `MostRecentWindowLaidOutStart.part`).
    var windowId: String?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousComments: () -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    let openCreateComment: () -> Void
    let deleteComment: (String) -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (ReportTarget) -> Void

    @State private var windowLaidOutStart = MostRecentWindowLaidOutStart()

    var body: some View {
        if !comments.isEmpty {
            if listsMostRecentEnd && hasMoreData && !hideLoader {
                Compat.ProgressView()
                    .frame(width: 100)
                    .frame(maxWidth: .infinity)
                    // The scroll view loads older comments while it is on screen.
                    .tracksOnScreenPresence()
            }
            if let laidOutPart {
                // Older and newer pages are lazy, the window they surround is laid out at once (see
                // `MostRecentWindow.laidOutStart` and `MostRecentWindow.laidOutEnd`).
                ForEach(comments[..<laidOutPart.lowerBound], id: \.uuid, content: row)
                VStack(spacing: 0) {
                    ForEach(comments[laidOutPart], id: \.uuid, content: row)
                }
                // A lazy stack scrolls to its own children only, laid out or not: the scroll keeping the first
                // comment of the part in place, once older ones are inserted above it, and the one to the comment the
                // screen opened on reach them through the part.
                .id(ResponseKind.comment.laidOutPartScrollAnchorId)
                ForEach(comments[laidOutPart.upperBound...], id: \.uuid, content: row)
            } else {
                ForEach(comments, id: \.uuid, content: row)
            }
            if listsMostRecentEnd && hasNewerData {
                Compat.ProgressView()
                    .frame(width: 100)
                    .frame(maxWidth: .infinity)
                    // The scroll view loads newer comments while it is on screen: `onAppear` would fire as soon as a
                    // lazy stack builds the loader ahead of the screen, and never in a list laid out whole.
                    .tracksOnScreenPresence(as: .newerItemsLoader)
            }
            if !listsMostRecentEnd && hasMoreData && !hideLoader {
                Compat.ProgressView()
                    .frame(width: 100)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        if #available(iOS 14, *) { Logger.posts.trace("Loader appeared, loading previous items...") }
                        loadPreviousComments()
                    }
            }
        } else {
            // The whole state stays tappable, as it was before the Screen states migration: it is the
            // fastest way into the composer from a post nobody has commented yet.
            Button(action: openCreateComment) {
                ScreenState(image: theme.assets.icons.screenStates.emptyContent,
                            title: .tonedKey(
                                formal: "Post.Detail.NoComments.Formal",
                                informal: "Post.Detail.NoComments.Informal"),
                            verticalPadding: ScreenState.postEmptyPadding)
            }.buttonStyle(.plain)
        }
    }

    /// The indices of the laid out part of the window in `comments`, or `nil` when they are not a window of the thread.
    private var laidOutPart: Range<Int>? {
        guard listsMostRecentEnd else {
            windowLaidOutStart.reset()
            return nil
        }
        return windowLaidOutStart.part(in: comments.map(\.uuid), pagesNewer: hasNewerData, windowId: windowId)
    }

    private func row(_ comment: DisplayableFeedResponse) -> some View {
        ResponseFeedItemView(
            response: comment,
            zoomableImageInfo: $zoomableImageInfo,
            displayResponseDetail: displayCommentDetail,
            displayProfile: displayProfile, deleteResponse: deleteComment,
            blockAuthor: blockAuthor,
            reactionTapped: reactionTapped,
            displayContentModeration: displayContentModeration)
        .id(comment.kind.scrollAnchorId(for: comment.uuid))
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
        // The scroll view follows a newer one only while the newest is on screen.
        .tracksOnScreenPresence(as: .newestItem, when: listsMostRecentEnd && comment.uuid == comments.last?.uuid)
    }
}
