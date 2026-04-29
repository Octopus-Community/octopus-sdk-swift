//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import OctopusCore
import SwiftUI

// MARK: - Main View

/// Shared post renderer used in both feed (summary) and detail contexts.
///
/// Owns the delete-confirmation alert and the iOS 13 action-sheet state, then
/// delegates all layout to the private `PostContentView`.
struct PostView: View {
    @Environment(\.octopusTheme) private var theme

    let post: PostViewData
    let context: PostViewContext
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?

    let reactionTapped: (ReactionKind?) -> Void
    let voteOnPoll: (String) -> Bool
    let displayProfile: (String) -> Void
    let deletePost: () -> Void
    let blockAuthor: (String) -> Void
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?
    let openCreateComment: () -> Void

    @State private var displayDeleteAlert = false
    @State private var displayBlockAlert = false
    @State private var iOS13ActionSheetIsPresented = false

    var body: some View {
        PostContentView(
            post: post,
            context: context,
            width: width,
            zoomableImageInfo: $zoomableImageInfo,
            iOS13ActionSheetIsPresented: $iOS13ActionSheetIsPresented,
            onDelete: { displayDeleteAlert = true },
            onReport: { displayContentModeration(post.uuid) },
            onBlockAuthor: { displayBlockAlert = true },
            onReaction: reactionTapped,
            onVote: voteOnPoll,
            onOpenCreateComment: openCreateComment,
            displayProfile: displayProfile,
            displayClientObject: displayClientObject)
        .destructiveConfirmationAlert(
            "Post.Delete.Confirmation.Title",
            isPresented: $displayDeleteAlert,
            destructiveLabel: "Common.Delete",
            action: deletePost)
        .destructiveConfirmationAlert(
            "Block.Profile.Alert.Title",
            isPresented: $displayBlockAlert,
            destructiveLabel: "Common.Continue",
            action: {
                if let profileId = post.author.profileId {
                    blockAuthor(profileId)
                }
            },
            message: "Block.Profile.Alert.Message")
        .actionSheet(isPresented: $iOS13ActionSheetIsPresented) {
            ActionSheet(
                title: Text("ActionSheet.Title", bundle: .module),
                buttons: iOS13ActionSheetButtons)
        }
    }

    private var iOS13ActionSheetButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if post.canBeDeleted {
            buttons.append(.destructive(Text("Post.Delete.Button", bundle: .module)) {
                displayDeleteAlert = true
            })
        }
        if post.canBeModerated {
            buttons.append(.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(post.uuid)
            })
        }
        if post.canBeBlockedByUser {
            buttons.append(.destructive(Text("Block.Profile.Button", bundle: .module)) {
                displayBlockAlert = true
            })
        }
        buttons.append(.cancel())
        return buttons
    }
}

// MARK: - Content View (pure renderer)

private struct PostContentView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager

    let post: PostViewData
    let context: PostViewContext
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    @Binding var iOS13ActionSheetIsPresented: Bool

    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlockAuthor: () -> Void
    let onReaction: (ReactionKind?) -> Void
    let onVote: (String) -> Bool
    let onOpenCreateComment: () -> Void
    let displayProfile: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PostHeaderView(
                context: context,
                author: post.author,
                relativeDate: post.relativeDate,
                topic: post.topic,
                displayGroupName: displayGroupName,
                groupTap: groupTap,
                canBeDeleted: post.canBeDeleted,
                canBeModerated: post.canBeModerated,
                canBeBlockedByUser: post.canBeBlockedByUser,
                displayProfile: displayProfile,
                onDelete: onDelete,
                onReport: onReport,
                onBlockAuthor: onBlockAuthor,
                iOS13ActionSheetIsPresented: $iOS13ActionSheetIsPresented)

            switch post.content {
            case let .published(content):
                publishedContentView(content)
            case let .moderated(reasons):
                moderatedContentView(reasons)
            }
        }
        .modify { view in
            if case let .summary(onCardTap, _, _) = context {
                view.contentShape(Rectangle())
                    .onTapGesture(perform: onCardTap)
            } else {
                view
            }
        }
    }

    @ViewBuilder
    private func publishedContentView(_ content: PostPublishedContent) -> some View {
        PublishedContentView(
            post: post,
            content: content,
            context: context,
            width: width,
            zoomableImageInfo: $zoomableImageInfo,
            onReaction: onReaction,
            onVote: onVote,
            onOpenCreateComment: onOpenCreateComment,
            displayClientObject: displayClientObject)
    }

    @ViewBuilder
    private func moderatedContentView(_ reasons: [DisplayableString]) -> some View {
        let joinedReasons = reasons
            .map { $0.localizedString(locale: languageManager.overridenLocale) }
            .joined(separator: ", ")
        PostTagsView(tags: post.tags)
        PostCatchPhraseView(localizedKey: "Post.List.ModeratedPost.MainText")
        PostTextContentView(
            localizedKey: "Post.List.ModeratedPost.Reason_reasons:\(joinedReasons)")
        .padding(.bottom, 8)
    }

    // MARK: Context helpers

    private var displayGroupName: Bool {
        if case let .summary(_, _, show) = context { return show }
        return true
    }

    private var groupTap: (() -> Void)? {
        if case let .summary(onCardTap, _, _) = context { return onCardTap }
        return nil
    }
}

// MARK: - Published content sub-view

/// Renders the body of a published (non-moderated) post. Owns the `liveMeasures` state
/// and subscribes to the publisher so the aggregated info and action bar react to updates.
private struct PublishedContentView: View {
    @Environment(\.octopusTheme) private var theme

    let post: PostViewData
    let content: PostPublishedContent
    let context: PostViewContext
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?

    let onReaction: (ReactionKind?) -> Void
    let onVote: (String) -> Bool
    let onOpenCreateComment: () -> Void
    let displayClientObject: ((String) -> Void)?

    @State private var liveMeasures: LiveMeasures

    init(post: PostViewData,
         content: PostPublishedContent,
         context: PostViewContext,
         width: CGFloat,
         zoomableImageInfo: Binding<ZoomableImageInfo?>,
         onReaction: @escaping (ReactionKind?) -> Void,
         onVote: @escaping (String) -> Bool,
         onOpenCreateComment: @escaping () -> Void,
         displayClientObject: ((String) -> Void)?) {
        self.post = post
        self.content = content
        self.context = context
        self.width = width
        self._zoomableImageInfo = zoomableImageInfo
        self.onReaction = onReaction
        self.onVote = onVote
        self.onOpenCreateComment = onOpenCreateComment
        self.displayClientObject = displayClientObject
        self._liveMeasures = State(initialValue: content.liveMeasuresValue)
    }

    /// The summary-context card-tap closure, or `nil` in `.detail`. Exposed so that children
    /// wrapped in a `Button` (which would otherwise swallow the parent `.onTapGesture`) can
    /// re-plug the tap — e.g. the view-count count inside `PostAggregatedInfoView`.
    private var cardTap: (() -> Void)? {
        if case let .summary(onCardTap, _, _) = context { return onCardTap }
        return nil
    }

    /// The summary-context "children count" tap closure — fired when the user taps the
    /// `XX Comments` CTA in `PostAggregatedInfoView`. Distinct from `openCreateComment`
    /// (which opens the keyboard): tapping the count should open the detail scrolled to
    /// the latest comment, without opening the composer.
    private var childrenTap: (() -> Void)? {
        if case let .summary(_, onChildrenTap, _) = context { return onChildrenTap }
        return nil
    }

    var body: some View {
        PostTagsView(tags: post.tags)

        if let catchPhrase = content.catchPhrase {
            PostCatchPhraseView(contentId: post.uuid, catchPhrase: catchPhrase)
        }

        PostTextContentView(
            contentId: post.uuid,
            text: content.text)

        // Figma order: text → poll → translation toggle → media → CTA.
        if case let .poll(poll) = content.attachment {
            PostPollContentView(
                postId: post.uuid,
                poll: poll,
                liveMeasuresPublisher: content.liveMeasuresPublisher,
                initialLiveMeasures: content.liveMeasuresValue,
                vote: onVote)
                .padding(.top, 4)
        }

        if content.text.hasTranslation {
            PostTranslationToggleView(
                contentId: post.uuid,
                originalLanguage: content.text.originalLanguage)
        }

        switch content.attachment {
        case .image, .video:
            if let attachment = content.attachment {
                PostMediaContentView(
                    postId: post.uuid,
                    width: width,
                    attachment: attachment,
                    zoomableImageInfo: $zoomableImageInfo,
                    visiblePost: post.visiblePost)
                    .padding(.top, 4)
            }
        case .poll, .none:
            EmptyView()
        }

        if let cta = content.cta {
            PostCTAContentView(
                postId: post.uuid,
                cta: cta,
                displayClientObject: displayClientObject)
        }

        PostAggregatedInfoView(
            aggregatedInfo: liveMeasures.aggregatedInfo,
            reactionTapped: onReaction,
            // The `XX Comments` CTA is intentionally different from `onOpenCreateComment`:
            // tapping the count opens the detail scrolled to the latest comment WITHOUT
            // opening the composer keyboard, while the action-bar "Comment" button opens
            // the composer. Wire it to the context's `onChildrenTap` in `.summary`; in
            // `.detail` we're already on the detail screen — no-op.
            childrenTapped: childrenTap ?? {},
            // Same rationale as `childrenTapped`: the view count is wrapped in a `Button`
            // inside `PostAggregatedInfoView` which blocks the parent's
            // `.onTapGesture(perform: onCardTap)`, so we forward the card tap here. In
            // `.detail` context — no-op.
            viewCountTapped: cardTap ?? {})
            .padding(.horizontal, theme.sizes.horizontalPadding)

        theme.colors.gray300
            .frame(height: 1)
            .padding(.horizontal, theme.sizes.horizontalPadding)

        PostActionBarView(
            userReaction: liveMeasures.userInteractions.reaction,
            reactionTapped: onReaction,
            commentTapped: onOpenCreateComment)
            .padding(.horizontal, theme.sizes.horizontalPadding)

        EmptyView()
            .onReceive(content.liveMeasuresPublisher) { liveMeasures = $0 }
            // Also react to `content.liveMeasuresValue` changes: the post detail view builds
            // its `PostViewData` from a static snapshot (`PostDetailViewModel.Post` doesn't
            // expose a publisher for the post's aggregated info / user interactions), so
            // `liveMeasuresPublisher` is `Empty` in that case and only the snapshot updates
            // when the underlying post changes. Without this, a tap on the like button would
            // fire the closure but the visible reaction state would stay stuck.
            .onValueChanged(of: content.liveMeasuresValue) { liveMeasures = $0 }
    }

}

// MARK: - Previews

#Preview("Summary — text only, group link, more menu") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        PostView(
            post: PostViewData(from: PostView.Previews.samplePost(
                text: "Un texte",
                reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5)
                ],
                childCount: 5, viewCount: 4,
                canBeDeleted: true)),
            context: .summary(onCardTap: {}, onChildrenTap: {}, displayGroupName: true),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _ in },
            deletePost: {},
            blockAuthor: { _ in },
            displayContentModeration: { _ in },
            displayClientObject: nil,
            openCreateComment: {})
    }
    .mockEnvironmentForPreviews()
}

#Preview("Summary — text + image, moderated tag") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        PostView(
            post: PostViewData(from: PostView.Previews.samplePost(
                text: "Un texte",
                attachment: .image(.init(
                    url: URL(string: "https://picsum.photos/700/750")!,
                    size: CGSize(width: 700, height: 750))),
                reactions: [.init(reactionKind: .heart, count: 10)],
                childCount: 3, viewCount: 20)),
            context: .summary(onCardTap: {}, onChildrenTap: {}, displayGroupName: false),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _ in },
            deletePost: {},
            blockAuthor: { _ in },
            displayContentModeration: { _ in },
            displayClientObject: nil,
            openCreateComment: {})
    }
    .mockEnvironmentForPreviews()
}

#Preview("Summary — text + poll") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        PostView(
            post: PostViewData(from: PostView.Previews.samplePost(
                text: "Un sondage",
                attachment: .poll(DisplayablePoll(options: [
                    .init(id: "1",
                          text: .init(originalText: "Option 1", originalLanguage: "fr",
                                      translatedText: "Option 1")),
                    .init(id: "2",
                          text: .init(originalText: "Option 2", originalLanguage: "fr",
                                      translatedText: "Option 2"))
                ])),
                childCount: 2, viewCount: 10)),
            context: .summary(onCardTap: {}, onChildrenTap: {}, displayGroupName: true),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _ in },
            deletePost: {},
            blockAuthor: { _ in },
            displayContentModeration: { _ in },
            displayClientObject: nil,
            openCreateComment: {})
    }
    .mockEnvironmentForPreviews()
}

#Preview("Detail — text + image + CTA") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        ScrollView {
            PostView(
                post: PostViewData(from: PostView.Previews.samplePost(
                    text: "Un texte avec image",
                    topic: "Design",
                    attachment: .image(.init(
                        url: URL(string: "https://picsum.photos/700/400")!,
                        size: CGSize(width: 700, height: 400))),
                    reactions: [.init(reactionKind: .heart, count: 42)],
                    childCount: 8, viewCount: 100,
                    canBeModerated: false)),
                context: .detail,
                width: 393,
                zoomableImageInfo: zoomable,
                reactionTapped: { _ in },
                voteOnPoll: { _ in false },
                displayProfile: { _ in },
                deletePost: {},
                blockAuthor: { _ in },
                displayContentModeration: { _ in },
                displayClientObject: nil,
                openCreateComment: {})
        }
    }
    .mockEnvironmentForPreviews()
}

// MARK: - Preview helper

/// Fixture builder shared by every `#Preview` in this file. Avoids ~50 lines of duplicated
/// `DisplayablePost` boilerplate per preview — mirrors the `ResponseView.Previews.sampleResponse`
/// pattern.
extension PostView {
    enum Previews {
        static func samplePost(
            text: String = "Un texte",
            originalLanguage: String? = "fr",
            translatedText: String? = "A text",
            topic: String = "Help",
            attachment: DisplayablePost.PostContent.Attachment? = nil,
            reactions: [ReactionCount] = [],
            childCount: Int = 0,
            viewCount: Int = 0,
            canBeDeleted: Bool = false,
            canBeModerated: Bool = true,
            canBeBlockedByUser: Bool = true
        ) -> DisplayablePost {
            let author = Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000")))

            let measures = CurrentValueSubject<LiveMeasures, Never>(LiveMeasures(
                aggregatedInfo: .init(reactions: reactions,
                                      childCount: childCount,
                                      viewCount: viewCount,
                                      pollResult: nil),
                userInteractions: .empty))

            return DisplayablePost(
                uuid: "postUuid",
                author: author,
                relativeDate: "3d ago",
                topic: topic,
                canBeDeleted: canBeDeleted,
                canBeModerated: canBeModerated,
                canBeBlockedByUser: canBeBlockedByUser,
                canBeOpened: true,
                content: .published(.init(
                    text: .init(originalText: text,
                                originalLanguage: originalLanguage,
                                translatedText: translatedText),
                    attachment: attachment,
                    bridgeInfo: nil,
                    customAction: nil,
                    featuredComment: nil,
                    liveMeasuresPublisher: measures)),
                position: 1,
                isLast: false,
                displayEvents: .init(onAppear: {}, onDisappear: {}))
        }
    }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content
    init(initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}
