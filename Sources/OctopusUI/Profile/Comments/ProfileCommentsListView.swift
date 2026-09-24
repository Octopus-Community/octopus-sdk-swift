//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Combine
import Octopus
import OctopusCore

/// The profile "Comments" tab: the member's authored comments & replies with their parent
/// context, newest-first. Each entry reuses the feed components — `PostSummaryView` for the parent post
/// and `ResponseFeedItemView` for the comment/reply (and the parent comment, for a reply) — so the cell
/// matches the feed's look (reactions, media, counts, "see replies").
///
/// Navigation matches the normal feed exactly: tapping the post / "Comment" opens the post detail
/// (`displayPostDetail`), and tapping a comment / reply / "Reply" opens the comment detail
/// (`displayCommentDetail`) — for a reply, the parent comment's detail scrolled to the reply.
struct ProfileCommentsListView: View {
    /// Observed, not owned: the screen's own view model creates this one and replaces it whenever the
    /// feed to list changes — a profile cached before the comment feed existed carries an empty feed id
    /// until the next fetch fills it in, and an Activity screen can move from one member to another. A
    /// `StateObject` would keep the instance it was first handed and ignore every replacement, leaving
    /// the tab stuck on the first (possibly empty) feed for as long as the view lives.
    @ObservedObject private var viewModel: ProfileCommentsListViewModel

    /// Opens the post detail (same signature and semantics as `PostFeedView.displayPostDetail`).
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToMostRecentComment: Bool,
                            _ commentToScrollTo: String?, _ hasFeaturedComment: Bool) -> Void
    /// Opens the comment detail (`commentId`), optionally focusing the reply composer (`reply`) and
    /// scrolling to a specific reply (`replyToScrollTo`).
    let displayCommentDetail: (_ commentId: String, _ reply: Bool, _ replyToScrollTo: String?) -> Void

    @State private var zoomableImageInfo: ZoomableImageInfo?

    init(viewModel: ProfileCommentsListViewModel,
         displayPostDetail: @escaping (_ postId: String, _ comment: Bool, _ scrollToMostRecentComment: Bool,
                                       _ commentToScrollTo: String?, _ hasFeaturedComment: Bool) -> Void,
         displayCommentDetail: @escaping (_ commentId: String, _ reply: Bool, _ replyToScrollTo: String?) -> Void) {
        _viewModel = .init(wrappedValue: viewModel)
        self.displayPostDetail = displayPostDetail
        self.displayCommentDetail = displayCommentDetail
    }

    var body: some View {
        ContentView(comments: viewModel.comments,
                    isOwnProfile: viewModel.isOwnProfile,
                    loadFailure: viewModel.loadFailure,
                    onRetry: { Task { await viewModel.retry() } },
                    zoomableImageInfo: $zoomableImageInfo,
                    displayPostDetail: displayPostDetail,
                    displayCommentDetail: displayCommentDetail,
                    onReaction: { reaction, contentId in viewModel.setReaction(reaction, contentId: contentId) },
                    onRowAppear: { item in Task { await viewModel.loadMoreIfNeeded(currentItem: item) } })
            // Keyed on the feed id rather than on `onAppear`: the view model can be replaced while the
            // tab stays on screen (see the property above), and the feed id is what says the thing to
            // list has changed. `refresh()` is idempotent, so re-entering a loaded feed costs nothing.
            .onValueChanged(of: viewModel.feedId, initial: true) { _ in
                Task { await viewModel.refresh() }
            }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let comments: [DisplayableUserComment]?
    let isOwnProfile: Bool
    let loadFailure: ScreenStateFailure?
    let onRetry: () -> Void
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayPostDetail: (String, Bool, Bool, String?, Bool) -> Void
    let displayCommentDetail: (String, Bool, String?) -> Void
    let onReaction: (ReactionKind?, String) -> Void
    let onRowAppear: (DisplayableUserComment) -> Void

    @State private var width: CGFloat = 0

    var body: some View {
        // `comments` stays nil until the first load settles here, so "loaded once" is exactly that.
        switch contentAreaState(itemCount: comments?.count, hasLoadedOnce: comments != nil,
                                loadFailure: loadFailure) {
        case let .failure(loadFailure):
            loadFailure.screenState(verticalPadding: Self.verticalPadding, icons: theme.assets.icons,
                                    retry: onRetry)
        case .empty, .content:
            if comments?.isEmpty ?? true {
                // On another member's profile the wording stays neutral: it must not reveal whether
                // comments were filtered out by access rights or simply never written.
                ScreenState(
                    image: theme.assets.icons.screenStates.emptyContent,
                    title: .localizationKey(isOwnProfile
                        ? "Profile.Comments.EmptyState.Title.Self"
                        : "Profile.Comments.EmptyState.Title.Other"),
                    verticalPadding: Self.verticalPadding)
            } else {
                Compat.LazyVStack(spacing: 0) {
                    ForEach(comments ?? []) { entry in
                        UserCommentCell(entry: entry, width: width,
                                        zoomableImageInfo: $zoomableImageInfo,
                                        displayPostDetail: displayPostDetail,
                                        displayCommentDetail: displayCommentDetail,
                                        onReaction: onReaction)
                            .onAppear { onRowAppear(entry) }
                        // 2px hairline between entries (design) — not the feed's thick 8px
                        // inter-post band.
                        theme.colors.gray300.frame(height: 2)
                    }
                }
                .readWidth($width)
            }
        case .loader:
            Compat.ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 130)
        }
    }

    /// The profile's screen states sit 80pt from the top and bottom of the content area (design).
    private static let verticalPadding: CGFloat = 80
}

/// One entry: the parent post (as a feed post summary) + the member's comment/reply (feed response card),
/// preceded by the parent comment when the entry is a reply.
///
/// The member's own comment/reply is highlighted with a light-blue card (`primaryLowContrast`). When the
/// entry is a reply, the parent comment is shown above it (plain gray card) and the reply is indented with
/// a `↳` corner arrow in the gutter, matching the feed's reply layout (Figma zRPfGOIUdcNwgdg1R9yw03).
private struct UserCommentCell: View {
    @Environment(\.octopusTheme) private var theme

    let entry: DisplayableUserComment
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayPostDetail: (String, Bool, Bool, String?, Bool) -> Void
    let displayCommentDetail: (String, Bool, String?) -> Void
    let onReaction: (ReactionKind?, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PostSummaryView(
                post: entry.post,
                width: width,
                displayGroup: true,
                zoomableImageInfo: $zoomableImageInfo,
                displayPostDetail: displayPostDetail,
                displayCommentDetail: { id, reply in displayCommentDetail(id, reply, nil) },
                displayProfile: { _, _ in },
                openGroup: { _ in },
                deletePost: { _ in },
                deleteComment: { _ in },
                blockAuthor: { _ in },
                reactionTapped: { reaction, postId in onReaction(reaction, postId) },
                commentReactionTapped: { reaction, commentId in onReaction(reaction, commentId) },
                voteOnPoll: { _, _ in false },
                displayContentModeration: { _ in },
                displayClientObject: nil,
                showsBottomSeparator: false)

            if let parentComment = entry.parentComment {
                // Reply: the parent comment (plain gray) is itself a top-level comment on the post, so
                // tapping it opens the *post* detail — same as tapping the post. The indented reply (with
                // the ↳ arrow) opens the parent comment's detail scrolled to the reply. "See N other
                // replies" (the parent's other replies) sits under the member's own bubble, opening that
                // thread.
                responseCard(parentComment, backgroundColor: nil,
                             detailCommentId: parentComment.uuid, replyToScrollTo: nil,
                             onCardTap: {
                                 displayPostDetail(entry.post.uuid, false, false, nil,
                                                   entry.post.hasFeaturedComment)
                             })
                HStack(alignment: .top, spacing: 0) {
                    ReplyArrow()
                        .frame(width: 13, height: 14)
                        // Occupy the same 32+12 gutter the feed uses to align a reply under its comment,
                        // with the arrow at the trailing edge of the gutter, level with the reply avatar.
                        .frame(width: 32 + 12, alignment: .trailing)
                        .padding(.top, 10)
                    responseCard(entry.response, backgroundColor: theme.colors.primaryLowContrast,
                                 detailCommentId: parentComment.uuid, replyToScrollTo: entry.response.uuid)
                }
                // "See N other replies" = the parent's other replies (childCount − 1, excluding the member's
                // own), driven by `parentComment`'s live measures. `extraLeading` = the reply gutter, so the
                // row lines up under the reply's bubble (not the parent comment's).
                SeeRepliesRow(source: parentComment, subtractSelf: true, otherWording: true,
                              extraLeading: 32 + 12) {
                    displayCommentDetail(parentComment.uuid, false, nil)
                }
            } else {
                // The member's own top-level comment, highlighted. Tapping the card opens the *post* detail
                // (same as tapping the post above it) — a top-level comment is read in the context of its
                // post, not its own thread. "Reply" still opens the comment thread (see `responseCard`).
                // "See N replies" (the replies to that comment) sits under the bubble and opens the thread.
                responseCard(entry.response, backgroundColor: theme.colors.primaryLowContrast,
                             detailCommentId: entry.response.uuid, replyToScrollTo: nil,
                             onCardTap: {
                                 displayPostDetail(entry.post.uuid, false, false, nil,
                                                   entry.post.hasFeaturedComment)
                             })
                SeeRepliesRow(source: entry.response, subtractSelf: false, otherWording: false) {
                    displayCommentDetail(entry.response.uuid, false, nil)
                }
            }
        }
    }

    /// Renders one comment/reply card. By default, tapping the card or "Reply" opens `detailCommentId`'s
    /// comment detail (scrolling to `replyToScrollTo` when set) — the same destinations as the feed. Pass
    /// `onCardTap` to override the card tap only (e.g. a top-level comment opens its post detail instead);
    /// "Reply" always goes to the comment detail. The card's own "See replies" row is suppressed
    /// (`displayChildCount: false`); the cell shows its own "See N (other) replies" row below the member's
    /// bubble instead.
    private func responseCard(_ response: DisplayableFeedResponse, backgroundColor: Color?,
                              detailCommentId: String, replyToScrollTo: String?,
                              onCardTap: (() -> Void)? = nil) -> some View {
        ResponseFeedItemView(
            response: response,
            displayChildCount: false,
            onCardTap: onCardTap ?? { displayCommentDetail(detailCommentId, false, replyToScrollTo) },
            cardBackgroundColor: backgroundColor,
            zoomableImageInfo: $zoomableImageInfo,
            displayResponseDetail: { _, reply in displayCommentDetail(detailCommentId, reply, replyToScrollTo) },
            displayProfile: { _, _ in },
            deleteResponse: { _ in },
            blockAuthor: { _ in },
            reactionTapped: { reaction, contentId in onReaction(reaction, contentId) },
            displayContentModeration: { _ in })
    }

}

/// "See N replies" row shown under the member's own bubble, matching the feed's `ResponseSeeRepliesView`
/// look. The count is driven by `source`'s live measures (`childCount`, minus one when `subtractSelf` to
/// exclude the member's own reply from a parent's sibling count). The profile feed omits that `childCount`,
/// so the count is seeded from the current value and updated once the ViewModel's fetch lands it in the DB —
/// which is why the row appears on first load without leaving the screen. Hidden while the count is zero.
/// `otherWording` picks "N other replies" (a reply) vs "N replies" (a top-level comment).
private struct SeeRepliesRow: View {
    @Environment(\.octopusTheme) private var theme

    let source: DisplayableFeedResponse
    let subtractSelf: Bool
    let otherWording: Bool
    /// Extra leading beyond the standard avatar-column inset, used by the reply case to clear the reply
    /// gutter so the row aligns under the reply's bubble rather than the parent comment's.
    let extraLeading: CGFloat
    let onTap: () -> Void

    @State private var replyCount: Int

    init(source: DisplayableFeedResponse, subtractSelf: Bool, otherWording: Bool,
         extraLeading: CGFloat = 0, onTap: @escaping () -> Void) {
        self.source = source
        self.subtractSelf = subtractSelf
        self.otherWording = otherWording
        self.extraLeading = extraLeading
        self.onTap = onTap
        _replyCount = State(initialValue: Self.adjust(source.liveMeasuresValue.aggregatedInfo.childCount,
                                                 subtractSelf: subtractSelf))
    }

    private static func adjust(_ childCount: Int, subtractSelf: Bool) -> Int {
        subtractSelf ? max(childCount - 1, 0) : childCount
    }

    var body: some View {
        Group {
            if replyCount > 0 {
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Image(uiImage: theme.assets.icons.content.comment.seeReply)
                            .resizable()
                            .flipsForRightToLeftLayoutDirection(true)
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(theme.colors.primary)
                        Text(otherWording
                             ? "Profile.Comments.SeeOtherReplies_count:\(replyCount)"
                             : "Reply.See_count:\(replyCount)",
                             bundle: .module)
                            .font(theme.fonts.caption1)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 5)
                    .padding(.bottom, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        // Align with the card's content (and the feed's native "See replies" row): the leading inset is
        // the horizontal padding + the avatar column (`ResponseView` lays the row inside the VStack that
        // sits after the 32pt avatar and its 12pt trailing gap), so this row lines up under the bubble.
        .padding(.leading, theme.sizes.horizontalPadding + 32 + 12 + extraLeading)
        .onReceive(source.liveMeasures
            .map { Self.adjust($0.aggregatedInfo.childCount, subtractSelf: subtractSelf) }
            .removeDuplicates()) { replyCount = $0 }
    }
}

/// A `↳` corner arrow drawn in the theme's primary color, shown in the gutter to the left of a reply.
/// Drawn (rather than an asset) because the SDK's icon catalog has no corner/return arrow.
private struct ReplyArrow: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        ReplyArrowShape()
            .stroke(theme.colors.primary,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }
}

private struct ReplyArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 1.5
        let cornerRadius: CGFloat = 4
        let startX = rect.minX + inset
        let topY = rect.minY + inset
        let bottomY = rect.maxY - inset
        let arrowTipX = rect.maxX - inset
        let arrowHead: CGFloat = 3.5

        // Vertical segment coming down, then a rounded 90° turn to the right.
        path.move(to: CGPoint(x: startX, y: topY))
        path.addLine(to: CGPoint(x: startX, y: bottomY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: startX + cornerRadius, y: bottomY),
                          control: CGPoint(x: startX, y: bottomY))
        path.addLine(to: CGPoint(x: arrowTipX, y: bottomY))

        // Arrowhead pointing right.
        path.move(to: CGPoint(x: arrowTipX - arrowHead, y: bottomY - arrowHead))
        path.addLine(to: CGPoint(x: arrowTipX, y: bottomY))
        path.addLine(to: CGPoint(x: arrowTipX - arrowHead, y: bottomY + arrowHead))
        return path
    }
}

#if DEBUG
/// Deterministic fixtures for the profile Comments cell — used by the previews below and by the
/// ImageRenderer snapshot check that verifies the reply arrow + "See N other replies" row against the
/// design. Avatars/images are remote URLs, so they render blank in a headless snapshot; the
/// arrow geometry and row placement (what we verify) are unaffected.
enum ProfileCommentsPreviewFixtures {
    private static func author(_ nickname: String) -> Author {
        Author(
            profile: MinimalProfile(
                uuid: "profile-\(nickname)",
                nickname: nickname,
                avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                gamificationLevel: 1),
            gamificationLevel: GamificationLevel(
                level: 1, name: "", startAt: 0, nextLevelAt: 100,
                badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000")))
    }

    private static func liveMeasures(reactions: Int, children: Int) -> CurrentValueSubject<LiveMeasures, Never> {
        CurrentValueSubject(LiveMeasures(
            aggregatedInfo: .init(
                reactions: [.init(reactionKind: .heart, count: reactions)],
                childCount: children, viewCount: 0, pollResult: nil),
            userInteractions: .empty))
    }

    private static func post() -> DisplayablePost {
        DisplayablePost(
            uuid: "postUuid",
            author: author("PostAuthor"),
            relativeDate: "3d ago",
            topic: "Help",
            groupId: "groupUuid",
            canBeDeleted: false, canBeModerated: true, canBeBlockedByUser: true,
            canBeOpened: true, canCreateChildren: true,
            content: .published(.init(
                text: .init(originalText: "The parent post that gives context to the comment.",
                            originalLanguage: nil),
                attachment: nil, bridgeInfo: nil, customAction: nil, featuredComment: nil,
                liveMeasuresPublisher: liveMeasures(reactions: 10, children: 4))),
            position: 0, isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {}))
    }

    private static func response(kind: ResponseKind, uuid: String, text: String,
                                 reactions: Int, children: Int) -> DisplayableFeedResponse {
        DisplayableFeedResponse(
            kind: kind, uuid: uuid,
            text: .init(text: .init(originalText: text, originalLanguage: nil)),
            image: nil, author: author(uuid),
            relativeDate: "1h. ago",
            canBeDeleted: false, canBeModerated: true, canBeBlockedByUser: true, canCreateChildren: true,
            _liveMeasuresPublisher: liveMeasures(reactions: reactions, children: children),
            displayEvents: .init(onAppear: {}, onDisappear: {}))
    }

    /// A reply the member authored, under a parent comment that has replies → shows the `↳` arrow
    /// (reply indented under the parent comment). The parent comment keeps its native "See N replies" row.
    static var replyEntry: DisplayableUserComment {
        DisplayableUserComment(
            id: "replyId",
            post: post(),
            response: response(kind: .reply, uuid: "replyId", text: "My reply to Alice's comment.",
                               reactions: 2, children: 0),
            parentComment: response(kind: .comment, uuid: "parentCommentId",
                                    text: "Alice's top-level comment.", reactions: 5, children: 4))
    }

    /// A top-level comment the member authored that has 4 replies → shows the native "See 4 replies" row.
    static var commentEntry: DisplayableUserComment {
        DisplayableUserComment(
            id: "commentId",
            post: post(),
            response: response(kind: .comment, uuid: "commentId", text: "My top-level comment on the post.",
                               reactions: 7, children: 4),
            parentComment: nil)
    }

    /// The rendered cell for a given entry, at a realistic phone content width.
    @MainActor @ViewBuilder
    static func cell(_ entry: DisplayableUserComment, width: CGFloat = 375) -> some View {
        UserCommentCell(
            entry: entry, width: width, zoomableImageInfo: .constant(nil),
            displayPostDetail: { _, _, _, _, _ in }, displayCommentDetail: { _, _, _ in },
            onReaction: { _, _ in })
            .frame(width: width)
            .mockEnvironmentForPreviews()
    }
}

#Preview("Reply (arrow + See N other replies)") {
    ProfileCommentsPreviewFixtures.cell(ProfileCommentsPreviewFixtures.replyEntry)
}

#Preview("Top-level comment (See N other replies)") {
    ProfileCommentsPreviewFixtures.cell(ProfileCommentsPreviewFixtures.commentEntry)
}
#endif
