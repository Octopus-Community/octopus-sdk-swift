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
    @Environment(\.textTone) private var textTone
    @Environment(\.octopusTheme) private var theme

    let post: PostViewData
    let context: PostViewContext
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?

    let reactionTapped: (ReactionKind?) -> Void
    let voteOnPoll: (String) async -> Bool
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    let openGroup: (String) -> Void
    let deletePost: () -> Void
    let blockAuthor: (String) -> Void
    let displayContentModeration: (ReportTarget) -> Void
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
            onReport: { displayContentModeration(reportTarget) },
            onBlockAuthor: { displayBlockAlert = true },
            onReaction: reactionTapped,
            onVote: voteOnPoll,
            onOpenCreateComment: openCreateComment,
            displayProfile: displayProfile,
            openGroup: openGroup,
            displayClientObject: displayClientObject)
        .destructiveConfirmationAlert(
            textTone.key(formal: "Post.Delete.Confirmation.Title.Formal",
                         informal: "Post.Delete.Confirmation.Title.Informal"),
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
            message: textTone.key(formal: "Block.Profile.Alert.Message.Formal",
                                  informal: "Block.Profile.Alert.Message.Informal"))
        .actionSheet(isPresented: $iOS13ActionSheetIsPresented) {
            ActionSheet(
                title: Text(textTone.key(formal: "ActionSheet.Title.Formal",
                                         informal: "ActionSheet.Title.Informal"), bundle: .module),
                buttons: iOS13ActionSheetButtons)
        }
    }

    /// What the Report entries report, with the author the "Report sent" alert may offer to block.
    private var reportTarget: ReportTarget {
        .content(contentId: post.uuid, author: post.author, authorCanBeBlocked: post.canBeBlockedByUser)
    }

    private var iOS13ActionSheetButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        // "View group" is a non-destructive navigation action, so it comes first. Shown on every
        // surface except the group feed (where `displayGroupName` is false).
        if case let .summary(_, displayGroupName) = context, displayGroupName, let groupId = post.groupId {
            buttons.append(.default(Text("Post.Menu.ViewGroup.Button", bundle: .module)) {
                openGroup(groupId)
            })
        }
        if post.canBeDeleted {
            buttons.append(.destructive(Text("Post.Delete.Button", bundle: .module)) {
                displayDeleteAlert = true
            })
        }
        if post.canBeModerated {
            buttons.append(.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(reportTarget)
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
    @Environment(\.textTone) private var textTone
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var displayConfigManager: DisplayConfigManager

    let post: PostViewData
    let context: PostViewContext
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    @Binding var iOS13ActionSheetIsPresented: Bool

    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlockAuthor: () -> Void
    let onReaction: (ReactionKind?) -> Void
    let onVote: (String) async -> Bool
    let onOpenCreateComment: () -> Void
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    let openGroup: (String) -> Void
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
                onViewGroup: onViewGroup,
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
            if case let .summary(onCardTap, _) = context {
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
            imageTapOverride: PostTapActions.imageTapOverride(
                context: context,
                options: displayConfigManager.postOptions,
                cardTapOpensDetail: post.cardTapOpensDetail),
            onReaction: onReaction,
            onVote: onVote,
            onOpenCreateComment: onOpenCreateComment,
            displayClientObject: displayClientObject,
            displayProfile: displayProfile)
    }

    @ViewBuilder
    private func moderatedContentView(_ reasons: [DisplayableString]) -> some View {
        let joinedReasons = reasons
            .map { $0.localizedString(locale: languageManager.overridenLocale, tone: textTone) }
            .joined(separator: ", ")
        PostTagsView(tags: post.tags)
        PostCatchPhraseView(localizedKey: "Post.List.ModeratedPost.MainText")
        PostTextContentView(
            localizedKey: "Post.List.ModeratedPost.Reason_reasons:\(joinedReasons)")
        .padding(.bottom, 8)
    }

    // MARK: Context helpers

    private var displayGroupName: Bool {
        if case let .summary(_, show) = context { return show }
        return true
    }

    /// The "View group" menu action, or `nil` to hide the entry. Shown wherever the group name is
    /// shown (i.e. every surface except the group feed, which sets `displayGroupName == false`),
    /// as long as the post carries a group id.
    private var onViewGroup: (() -> Void)? {
        guard displayGroupName, let groupId = post.groupId else { return nil }
        return { openGroup(groupId) }
    }

    /// The group name tap: the card action in feeds and nothing in the detail, unless the community makes the
    /// group name open the group (see `PostTapActions.groupNameTapAction`).
    private var groupTap: (() -> Void)? {
        let openGroupFromName: (() -> Void)? = post.groupId.map { groupId in
            { [displayConfigManager, openGroup] in
                displayConfigManager.openGroupFromPost(groupId: groupId, open: openGroup)
            }
        }
        return PostTapActions.groupNameTapAction(
            context: context,
            options: displayConfigManager.postOptions,
            openGroup: openGroupFromName)
    }
}

// MARK: - Published content sub-view

/// Renders the body of a published (non-moderated) post. Owns the `liveMeasures` state
/// and subscribes to the publisher so the footer reacts to updates.
private struct PublishedContentView: View {
    let post: PostViewData
    let content: PostPublishedContent
    let context: PostViewContext
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    /// Replaces the fullscreen viewer when an image is tapped, `nil` to keep it.
    let imageTapOverride: (() -> Void)?

    let onReaction: (ReactionKind?) -> Void
    let onVote: (String) async -> Bool
    let onOpenCreateComment: () -> Void
    let displayClientObject: ((String) -> Void)?
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void

    @State private var liveMeasures: LiveMeasures

    init(post: PostViewData,
         content: PostPublishedContent,
         context: PostViewContext,
         width: CGFloat,
         zoomableImageInfo: Binding<ZoomableImageInfo?>,
         imageTapOverride: (() -> Void)?,
         onReaction: @escaping (ReactionKind?) -> Void,
         onVote: @escaping (String) async -> Bool,
         onOpenCreateComment: @escaping () -> Void,
         displayClientObject: ((String) -> Void)?,
         displayProfile: @escaping (_ profileId: String, _ clientUserId: String?) -> Void) {
        self.post = post
        self.content = content
        self.context = context
        self.width = width
        self._zoomableImageInfo = zoomableImageInfo
        self.imageTapOverride = imageTapOverride
        self.onReaction = onReaction
        self.onVote = onVote
        self.onOpenCreateComment = onOpenCreateComment
        self.displayClientObject = displayClientObject
        self.displayProfile = displayProfile
        self._liveMeasures = State(initialValue: content.liveMeasuresValue)
    }

    private func mediaView(_ media: PostAttachmentsViewData.Media) -> some View {
        PostMediaContentView(
            postId: post.uuid,
            width: width,
            media: media,
            zoomableImageInfo: $zoomableImageInfo,
            visiblePost: post.visiblePost,
            imageTapOverride: imageTapOverride)
    }

    /// Space above the media: 4, or 8 above images when the post has no text.
    private func mediaTopPadding(_ media: PostAttachmentsViewData.Media) -> CGFloat {
        if case .images = media, !content.text.hasText {
            return 8
        }
        return 4
    }

    var body: some View {
        // Design order: translation toggle → tags → catch phrase → text → media → poll → CTA. The toggle comes
        // first, right under the header, so that the member knows the content is translated before reading it.
        if content.hasTranslation {
            // The language is the post's own (it may be set without text); `nil` gives the generic
            // "See original" label. Poll options carry no language of their own.
            PostTranslationToggleView(
                contentId: post.uuid,
                originalLanguage: content.text.originalLanguage)
                // Its hit area spills over the blocks around it: it must be drawn above them to get those taps.
                .zIndex(1)
        }

        PostTagsView(tags: post.tags)

        if let catchPhrase = content.catchPhrase {
            PostCatchPhraseView(contentId: post.uuid, catchPhrase: catchPhrase)
        }

        // A post may carry an image without text: the empty block is skipped, and the images get more space
        // above them instead (see `mediaTopPadding`).
        if content.text.hasText {
            PostTextContentView(
                contentId: post.uuid,
                text: content.text)
        }

        if let media = content.attachments.media {
            mediaView(media)
                .padding(.top, mediaTopPadding(media))
                // With a poll below: 8 here + 4 (PostPollContentView top) + 4 (PollOptionView) = 16pt from the
                // media to the first option. With several images, it is counted from the dots below them.
                .padding(.bottom, content.attachments.poll == nil ? 0 : 8)
        }

        if let poll = content.attachments.poll {
            PostPollContentView(
                postId: post.uuid,
                poll: poll,
                liveMeasuresPublisher: content.liveMeasuresPublisher,
                initialLiveMeasures: content.liveMeasuresValue,
                vote: onVote)
                .padding(.top, content.attachments.media == nil ? 4 : 0)
        }

        if let cta = content.cta {
            PostCTAContentView(
                postId: post.uuid,
                cta: cta,
                displayClientObject: displayClientObject)
        }

        PostActionBarView(
            contentId: post.uuid,
            aggregatedInfo: liveMeasures.aggregatedInfo,
            userReaction: liveMeasures.userInteractions.reaction,
            displayCommentButton: post.canCreateChildren,
            reactionTapped: onReaction,
            commentTapped: onOpenCreateComment,
            displayProfile: displayProfile)

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
            context: .summary(onCardTap: {}, displayGroupName: true),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _, _ in },
            openGroup: { _ in },
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
                attachments: .images([.init(
                    url: URL(string: "https://picsum.photos/700/750")!,
                    size: CGSize(width: 700, height: 750))]),
                reactions: [.init(reactionKind: .heart, count: 10)],
                childCount: 3, viewCount: 20)),
            context: .summary(onCardTap: {}, displayGroupName: false),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _, _ in },
            openGroup: { _ in },
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
                attachments: .poll(DisplayablePoll(options: [
                    .init(id: "1",
                          text: .init(originalText: "Option 1", originalLanguage: "fr",
                                      translatedText: "Option 1")),
                    .init(id: "2",
                          text: .init(originalText: "Option 2", originalLanguage: "fr",
                                      translatedText: "Option 2"))
                ])),
                childCount: 2, viewCount: 10)),
            context: .summary(onCardTap: {}, displayGroupName: true),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _, _ in },
            openGroup: { _ in },
            deletePost: {},
            blockAuthor: { _ in },
            displayContentModeration: { _ in },
            displayClientObject: nil,
            openCreateComment: {})
    }
    .mockEnvironmentForPreviews()
}

#Preview("Summary — text + image + poll") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        PostView(
            post: PostViewData(from: PostView.Previews.samplePost(
                text: "Laquelle préférez-vous ?",
                attachments: PostView.Previews.imageAndPoll,
                childCount: 2, viewCount: 10)),
            context: .summary(onCardTap: {}, displayGroupName: true),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _, _ in },
            openGroup: { _ in },
            deletePost: {},
            blockAuthor: { _ in },
            displayContentModeration: { _ in },
            displayClientObject: nil,
            openCreateComment: {})
    }
    .mockEnvironmentForPreviews()
}

#Preview("Detail — text + image + poll") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        ScrollView {
            PostView(
                post: PostViewData(from: PostView.Previews.samplePost(
                    text: "Laquelle préférez-vous ?",
                    attachments: PostView.Previews.imageAndPoll,
                    childCount: 8, viewCount: 100)),
                context: .detail,
                width: 393,
                zoomableImageInfo: zoomable,
                reactionTapped: { _ in },
                voteOnPoll: { _ in false },
                displayProfile: { _, _ in },
                openGroup: { _ in },
                deletePost: {},
                blockAuthor: { _ in },
                displayContentModeration: { _ in },
                displayClientObject: nil,
                openCreateComment: {})
        }
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
                    attachments: .images([.init(
                        url: URL(string: "https://picsum.photos/700/400")!,
                        size: CGSize(width: 700, height: 400))]),
                    reactions: [.init(reactionKind: .heart, count: 42)],
                    childCount: 8, viewCount: 100,
                    canBeModerated: false)),
                context: .detail,
                width: 393,
                zoomableImageInfo: zoomable,
                reactionTapped: { _ in },
                voteOnPoll: { _ in false },
                displayProfile: { _, _ in },
                openGroup: { _ in },
                deletePost: {},
                blockAuthor: { _ in },
                displayContentModeration: { _ in },
                displayClientObject: nil,
                openCreateComment: {})
        }
    }
    .mockEnvironmentForPreviews()
}

#Preview("Summary — image, no text") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        PostView(
            post: PostViewData(from: PostView.Previews.samplePost(
                text: "", originalLanguage: nil, translatedText: nil,
                attachments: .images([.init(
                    url: URL(string: "https://picsum.photos/700/750")!,
                    size: CGSize(width: 700, height: 750))]),
                childCount: 1, viewCount: 3)),
            context: .summary(onCardTap: {}, displayGroupName: true),
            width: 393,
            zoomableImageInfo: zoomable,
            reactionTapped: { _ in },
            voteOnPoll: { _ in false },
            displayProfile: { _, _ in },
            openGroup: { _ in },
            deletePost: {},
            blockAuthor: { _ in },
            displayContentModeration: { _ in },
            displayClientObject: nil,
            openCreateComment: {})
    }
    .mockEnvironmentForPreviews()
}

#Preview("Detail — image + poll, no text") {
    StatefulPreviewWrapper(initial: ZoomableImageInfo?.none) { zoomable in
        ScrollView {
            PostView(
                post: PostViewData(from: PostView.Previews.samplePost(
                    text: "", originalLanguage: nil, translatedText: nil,
                    attachments: PostView.Previews.imageAndPoll,
                    childCount: 2, viewCount: 10)),
                context: .detail,
                width: 393,
                zoomableImageInfo: zoomable,
                reactionTapped: { _ in },
                voteOnPoll: { _ in false },
                displayProfile: { _, _ in },
                openGroup: { _ in },
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
        static let imageAndPoll = PostAttachmentsViewData(
            media: .images([.init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750))]),
            poll: DisplayablePoll(options: [
                .init(id: "1",
                      text: .init(originalText: "La rouge", originalLanguage: "fr",
                                  translatedText: "The red one")),
                .init(id: "2",
                      text: .init(originalText: "La bleue", originalLanguage: "fr",
                                  translatedText: "The blue one"))
            ]))

        static func samplePost(
            text: String = "Un texte",
            originalLanguage: String? = "fr",
            translatedText: String? = "A text",
            topic: String? = "Help",
            attachments: PostAttachmentsViewData = .empty,
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
                relativeDate: "3d",
                topic: topic,
                groupId: "groupUuid",
                canBeDeleted: canBeDeleted,
                canBeModerated: canBeModerated,
                canBeBlockedByUser: canBeBlockedByUser,
                canBeOpened: true,
                canCreateChildren: true,
                content: .published(.init(
                    text: .init(originalText: text,
                                originalLanguage: originalLanguage,
                                translatedText: translatedText),
                    attachments: attachments,
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
