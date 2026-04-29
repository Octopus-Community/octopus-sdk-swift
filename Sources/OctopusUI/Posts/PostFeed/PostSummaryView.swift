//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import OctopusCore

struct PostSummaryView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.trackingApi) private var trackingApi
    @EnvironmentObject private var languageManager: LanguageManager

    let post: DisplayablePost
    let width: CGFloat
    let displayGroup: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool,
                            _ scrollToComment: String?, _ hasFeaturedComment: Bool) -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (String) -> Void
    let deletePost: (String) -> Void
    let deleteComment: (String) -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let commentReactionTapped: (ReactionKind?, String) -> Void
    let voteOnPoll: (String, String) -> Bool
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    @State private var groupedForAccessibility = true

    var body: some View {
        VStack(spacing: 0) {
            PostView(
                post: PostViewData(from: post),
                context: .summary(
                    onCardTap: {
                        displayPostDetail(post.uuid, false, false, nil, post.hasFeaturedComment)
                    },
                    onChildrenTap: {
                        // Tapping the "XX Comments" count opens the detail scrolled to the
                        // latest comment WITHOUT opening the composer (`comment: false`).
                        // The action-bar "Comment" button is a separate closure that opens
                        // the composer (`comment: true`) — see `openCreateComment` below.
                        trackingApi.emit(event: .commentButtonClicked(.init(postId: post.uuid)))
                        displayPostDetail(post.uuid, false, true, nil, post.hasFeaturedComment)
                    },
                    displayGroupName: displayGroup),
                width: width,
                zoomableImageInfo: $zoomableImageInfo,
                reactionTapped: { reactionTapped($0, post.uuid) },
                voteOnPoll: { voteOnPoll($0, post.uuid) },
                displayProfile: displayProfile,
                deletePost: { deletePost(post.uuid) },
                blockAuthor: blockAuthor,
                displayContentModeration: displayContentModeration,
                displayClientObject: displayClientObject,
                openCreateComment: {
                    trackingApi.emit(event: .commentButtonClicked(.init(postId: post.uuid)))
                    displayPostDetail(post.uuid, true, true, nil, post.hasFeaturedComment)
                })

            // Featured comment (non-goal of OCT-1277 — kept in the wrapper; belongs to the comment ticket)
            if case let .published(published) = post.content,
               let featuredComment = published.featuredComment {
                ResponseFeedItemView(
                    response: featuredComment,
                    displayChildCount: false,
                    // Tapping the featured comment in a post summary should open the parent
                    // post's detail (scrolled to the featured comment), not the comment's own
                    // detail. The rest of the app (comment lists in post detail, reply lists
                    // in comment detail) leaves this `nil` so the card is not whole-card
                    // tappable — only the avatar, action bar, and "See N replies" row are.
                    onCardTap: {
                        displayPostDetail(post.uuid, false, false, featuredComment.uuid, post.hasFeaturedComment)
                    },
                    zoomableImageInfo: .constant(nil),
                    displayResponseDetail: displayCommentDetail,
                    displayProfile: displayProfile,
                    deleteResponse: deleteComment,
                    blockAuthor: blockAuthor,
                    reactionTapped: commentReactionTapped,
                    displayContentModeration: displayContentModeration)
                    // No outer `.padding(.horizontal, theme.sizes.horizontalPadding)` here:
                    // `ResponseView` already applies the same horizontal padding internally,
                    // so adding it at the call site doubles the inset (16 + 16 = 32).
            }

            theme.colors.gray300
                .frame(height: 2)
        }
        .id("post-\(post.uuid)-\(groupedForAccessibility)")
        .accessibilityElement(children: groupedForAccessibility ? .ignore : .contain)
        .accessibilityLabelInBundle(groupedForAccessibility ? accessibilityDescription : nil)
        .accessibilityAction(named: Text(
            groupedForAccessibility
                ? "Accessibility.Content.Action.ReadElements"
                : "Accessibility.Content.Action.ReadSummary",
            bundle: .module)) {
            groupedForAccessibility.toggle()
            refreshVoiceOverFocus(on: self)
        }
        .modify {
            if let authorId = post.author.profileId {
                $0.accessibilityAction(named: Text("Accessibility.Content.Action.ViewAuthor", bundle: .module)) {
                    displayProfile(authorId)
                }
            } else { $0 }
        }
        .accessibilityAction(named: Text("Accessibility.Content.Action.OpenDetail", bundle: .module)) {
            displayPostDetail(post.uuid, false, false, nil, post.hasFeaturedComment)
        }
        .modify {
            if #available(iOS 14.0, *) {
                $0.accessibilityHintInBundle("Accessibility.Post.List.OpenDetail.Hint")
            } else { $0 }
        }
    }

    var accessibilityDescription: LocalizedStringKey {
        let authorName = post.author.name.localizedString(locale: languageManager.overridenLocale)
        switch post.content {
        case let .published(postContent):
            let text = postContent.text.getText(translated: true)
            var textToRead = "\(text)\(postContent.text.getIsEllipsized(translated: true) ? "..." : "")"
            switch postContent.attachment {
            case .image: return "Accessibility.Post.Summary.TextAndImage_author:\(authorName)_date:\(post.relativeDate)_topic:\(post.topic)_text:\(textToRead)"
            case .video: return "Accessibility.Post.Summary.TextAndVideo_author:\(authorName)_date:\(post.relativeDate)_topic:\(post.topic)_text:\(textToRead)"
            case let .poll(poll):
                let pollOptionsToRead = poll.options.enumerated()
                    .map { index, pollOption in
                        let indexToRead = L10n("Accessibility.Poll.IdxOption_index:%lld_count:%lld", locale: languageManager.overridenLocale, index + 1, poll.options.count)
                        let pollOptionToRead = pollOption.text.getText(translated: true)
                        let isSelectedToRead = postContent.liveMeasuresValue.userInteractions.pollVoteId == pollOption.id ? L10n("Accessibility.Common.Selected", locale: languageManager.overridenLocale) : ""
                        return "\(indexToRead): \(pollOptionToRead)\(isSelectedToRead)"
                    }
                    .joined(separator: ", ")
                textToRead = "\(textToRead), \(pollOptionsToRead)"
                return "Accessibility.Post.Summary.TextOnly_author:\(authorName)_date:\(post.relativeDate)_topic:\(post.topic)_text:\(textToRead)"
            case .none:
                return "Accessibility.Post.Summary.TextOnly_author:\(authorName)_date:\(post.relativeDate)_topic:\(post.topic)_text:\(textToRead)"
            }

        case let .moderated(reasons):
            let localizedReasons = reasons
                .map { $0.localizedString(locale: languageManager.overridenLocale) }
                .joined(separator: ", ")
            return "Accessibility.Post.Summary.Moderated_author:\(authorName)_date:\(post.relativeDate)_reasons:\(localizedReasons)"
        }
    }
}

#Preview("Text only") {
    PostSummaryView(
        post: DisplayablePost(
            uuid: "postUuid",
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canBeOpened: true,
            content: .published(.init(
                text: .init(
                    originalText: "Un texte",
                    originalLanguage: "fr",
                    translatedText: "A text"),
                attachment: nil,
                bridgeInfo: nil,
                customAction: nil,
                featuredComment: nil,
                liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                    aggregatedInfo: .init(reactions: [
                        .init(reactionKind: .heart, count: 10),
                        .init(reactionKind: .clap, count: 5),
                    ], childCount: 5, viewCount: 4, pollResult: nil),
                    userInteractions: .empty)))),
            position: 1,
            isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {})),
        width: 0,
        displayGroup: true,
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Text and Image") {
    PostSummaryView(
        post: DisplayablePost(
            uuid: "postUuid",
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canBeOpened: true,
            content: .published(.init(
                text: .init(
                    originalText: "Un texte",
                    originalLanguage: "fr",
                    translatedText: "A text"),
                attachment: .image(.init(
                    url: URL(string: "https://picsum.photos/700/750")!,
                    size: CGSize(width: 700, height: 750))),
                bridgeInfo: nil,
                customAction: nil,
                featuredComment: nil,
                liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                    aggregatedInfo: .init(reactions: [
                        .init(reactionKind: .heart, count: 10),
                        .init(reactionKind: .clap, count: 5),
                    ], childCount: 5, viewCount: 4, pollResult: nil),
                    userInteractions: .empty)))),
            position: 1,
            isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {})),
        width: 0,
        displayGroup: true,
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Text and Poll") {
    PostSummaryView(
        post: DisplayablePost(
            uuid: "postUuid",
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canBeOpened: true,
            content: .published(.init(
                text: .init(
                    originalText: "Un texte\navec retour à la ligne",
                    originalLanguage: "fr",
                    translatedText: "A text\nwith a line break"),
                attachment: .poll(
                    DisplayablePoll(options: [
                        .init(id: "1", text: .init(
                            originalText: "Option 1",
                            originalLanguage: "fr",
                            translatedText: "Option 1")),
                        .init(id: "2", text: .init(
                            originalText: "Option 2",
                            originalLanguage: "fr",
                            translatedText: "Option 2"))
                    ])
                ),
                bridgeInfo: nil,
                customAction: nil,
                featuredComment: nil,
                liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                    aggregatedInfo: .init(reactions: [
                        .init(reactionKind: .heart, count: 10),
                        .init(reactionKind: .clap, count: 5),
                    ], childCount: 5, viewCount: 4, pollResult: nil),
                    userInteractions: .empty)))),
            position: 1,
            isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {})),
        width: 0,
        displayGroup: true,
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Text no translation") {
    PostSummaryView(
        post: DisplayablePost(
            uuid: "postUuid",
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canBeOpened: true,
            content: .published(.init(
                text: .init(
                    originalText: "Un texte\navec retour à la ligne",
                    originalLanguage: nil),
                attachment: .image(.init(
                    url: URL(string: "https://picsum.photos/700/750")!,
                    size: CGSize(width: 700, height: 750))),
                bridgeInfo: nil,
                customAction: nil,
                featuredComment: nil,
                liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                    aggregatedInfo: .init(reactions: [
                        .init(reactionKind: .heart, count: 10),
                        .init(reactionKind: .clap, count: 5),
                    ], childCount: 5, viewCount: 4, pollResult: nil),
                    userInteractions: .empty)))),
            position: 1,
            isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {})),
        width: 0,
        displayGroup: true,
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Bridge with Text and Image") {
    let ctaText = TranslatableText(
        originalText: "Voir",
        originalLanguage: "fr",
        translatedText: "View")
    PostSummaryView(
        post: DisplayablePost(
            uuid: "postUuid",
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canBeOpened: true,
            content: .published(.init(
                text: .init(
                    originalText: "Un texte",
                    originalLanguage: "fr",
                    translatedText: "A text"),
                attachment: .image(.init(
                    url: URL(string: "https://picsum.photos/700/750")!,
                    size: CGSize(width: 700, height: 750))),
                bridgeInfo: .init(
                    objectId: "clientObjectId",
                    catchPhrase: .init(
                        originalText: "Qu'en pensez vous ?",
                        originalLanguage: "fr",
                        translatedText: "What do you think?"),
                    ctaText: ctaText
                ),
                customAction: nil,
                featuredComment: nil,
                liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                    aggregatedInfo: .init(reactions: [
                        .init(reactionKind: .heart, count: 10),
                        .init(reactionKind: .clap, count: 5),
                    ], childCount: 5, viewCount: 4, pollResult: nil),
                    userInteractions: .empty)))),
            position: 1,
            isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {})),
        width: 0,
        displayGroup: true,
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Custom action with Text and Image") {
    let ctaText = TranslatableText(
        originalText: "Voir",
        originalLanguage: "fr",
        translatedText: "View")
    PostSummaryView(
        post: DisplayablePost(
            uuid: "postUuid",
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canBeOpened: true,
            content: .published(.init(
                text: .init(
                    originalText: "Un texte",
                    originalLanguage: "fr",
                    translatedText: "A text"),
                attachment: .image(.init(
                    url: URL(string: "https://picsum.photos/700/750")!,
                    size: CGSize(width: 700, height: 750))),
                bridgeInfo: nil,
                customAction: .init(ctaText: ctaText, targetUrl: URL(string: "https://www.example.com")!),
                featuredComment: nil,
                liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                    aggregatedInfo: .init(reactions: [
                        .init(reactionKind: .heart, count: 10),
                        .init(reactionKind: .clap, count: 5),
                    ], childCount: 5, viewCount: 4, pollResult: nil),
                    userInteractions: .empty)))),
            position: 1,
            isLast: false,
            displayEvents: .init(onAppear: {}, onDisappear: {})),
        width: 0,
        displayGroup: true,
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockEnvironmentForPreviews()
}
