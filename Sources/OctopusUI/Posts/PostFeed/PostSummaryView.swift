//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostSummaryView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var trackingApi: TrackingApi
    @EnvironmentObject private var languageManager: LanguageManager

    let post: DisplayablePost
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool, _ scrollToComment: String?, _ hasFeaturedComment: Bool) -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (String) -> Void
    let deletePost: (String) -> Void
    let deleteComment: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let commentReactionTapped: (ReactionKind?, String) -> Void
    let voteOnPoll: (String, String) -> Bool
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    @State private var openActions = false
    @State private var displayDeleteAlert = false

    @State private var displayReactionsCount = false

    @State private var groupedForAccessibility = true

    @Compat.ScaledMetric(relativeTo: .subheadline) var moreIconSize: CGFloat = 24 // subheadline to vary from 19 to 69
    @Compat.ScaledMetric(relativeTo: .title1) var authorAvatarSize: CGFloat = 40 // title1 to vary from 40 to 88

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Group { // group views to have the same horizontal padding
                    HStack(alignment: .top, spacing: 0) {
                        OpenProfileButton(author: post.author, displayProfile: displayProfile) {
                            HStack {
                                AuthorAvatarView(avatar: post.author.avatar)
                                    .frame(width: max(authorAvatarSize, 40), height: max(authorAvatarSize, 40))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            }
                            .frame(width: max(authorAvatarSize, 44), height: max(authorAvatarSize, 44))
                        }
                        .padding(.top, 16)

                        Spacer().frame(width: 4)

                        VStack(alignment: .leading, spacing: 0) {
                            AuthorAndDateHeaderView(
                                author: post.author, relativeDate: post.relativeDate,
                                topPadding: 16, displayProfile: displayProfile,
                                displayContent: { displayPostDetail(post.uuid, false, false, nil, post.hasFeaturedComment) })
                            HStack(spacing: 4) {
                                OpenDetailButton(
                                    post: post,
                                    displayPostDetail: { displayPostDetail($0, false, false, nil, post.hasFeaturedComment) }) {
                                        HStack {
                                            Text(post.topic)
                                                .octopusBadgeStyle(.small, status: .off)
                                            Spacer()
                                        }
                                        .padding(.top, 3)
                                    }
                                if case .moderated = post.content {
                                    Text("Post.Status.Moderated", bundle: .module)
                                        .font(theme.fonts.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.colors.error)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .foregroundColor(theme.colors.error.opacity(0.1))
                                        )
                                        .padding(.top, 3)
                                }
                            }
                        }
                        Spacer()
                        if post.canBeDeleted || post.canBeModerated {
                            if #available(iOS 14.0, *) {
                                Menu(content: {
                                    if post.canBeDeleted {
                                        Button(action: { displayDeleteAlert = true }) {
                                            Label(title: { Text("Post.Delete.Button", bundle: .module) },
                                                  icon: { Image(systemName: "trash") })
                                        }

                                    }
                                    if post.canBeModerated {
                                        Button(action: { displayContentModeration(post.uuid) }) {
                                            Label(title: { Text("Moderation.Content.Button", bundle: .module) },
                                                  icon: { Image(systemName: "flag") })
                                        }
                                    }
                                }, label: {
                                    HStack(alignment: .top) {
                                        Image(res: .more)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: max(moreIconSize, 24), height: max(moreIconSize, 24))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                            .foregroundColor(theme.colors.gray500)
                                            .accessibilityLabelInBundle("Accessibility.Common.More")
                                    }.frame(width: max(moreIconSize, 44), height: max(moreIconSize, 44))
                                })
                                .buttonStyle(.plain)
                                .padding(.top, 16)
                            } else {
                                Button(action: { openActions = true }) {
                                    Image(res: .more)
                                        .resizable()
                                        .frame(width: max(moreIconSize, 24), height: max(moreIconSize, 24))
                                        .foregroundColor(theme.colors.gray500)
                                        .accessibilityLabelInBundle("Accessibility.Common.More")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(.horizontal, 16)

                switch post.content {
                case let .published(postContent):
                    PublishedContentView(
                        content: postContent, post: post, contentId: post.uuid, width: width,
                        zoomableImageInfo: $zoomableImageInfo,
                        childrenTapped: {
                            let comment = postContent.liveMeasuresValue.aggregatedInfo.childCount == 0
                            if comment {
                                trackingApi.emit(event: .commentButtonClicked(.init(postId: post.uuid)))
                            }
                            displayPostDetail(post.uuid, comment, true, nil, post.hasFeaturedComment) },
                        reactionTapped: { reactionTapped($0, post.uuid) },
                        commentReactionTapped: commentReactionTapped,
                        voteOnPoll: { voteOnPoll($0, post.uuid) },
                        displayClientObject: displayClientObject,
                        displayPostDetail: { displayPostDetail(post.uuid, false, false, $0, post.hasFeaturedComment) },
                        displayCommentDetail: displayCommentDetail,
                        displayProfile: displayProfile,
                        deleteComment: deleteComment,
                        displayContentModeration: displayContentModeration
                    )
                case let .moderated(reasons):
                    ModeratedPostContentView(reasons: reasons)
                }
            }
            .padding(.bottom, 8)

            theme.colors.gray300
                .frame(height: 1)
        }
        .id("post-\(post.uuid)-\(groupedForAccessibility)")
        .accessibilityElement(children: groupedForAccessibility ? .ignore : .contain)
        .accessibilityLabelInBundle(groupedForAccessibility ? accessibilityDescription : nil)
        .accessibilityAction(named: Text(groupedForAccessibility ? "Accessibility.Content.Action.ReadElements" : "Accessibility.Content.Action.ReadSummary", bundle: .module)) {
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
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: actionSheetContent)
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Confirmation.Title", bundle: .module),
                    isPresented: $displayDeleteAlert) {
                        Button(role: .cancel, action: {}, label: { Text("Common.Cancel", bundle: .module) })
                        Button(role: .destructive, action: { deletePost(post.uuid) },
                               label: { Text("Common.Delete", bundle: .module) })
                    }
            } else {
                $0.alert(isPresented: $displayDeleteAlert) {
                    Alert(title: Text("Post.Delete.Confirmation.Title",
                                      bundle: .module),
                          primaryButton: .default(Text("Common.Cancel", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Delete", bundle: .module),
                            action: { deletePost(post.uuid) }
                          )
                    )
                }
            }
        }
    }

    var actionSheetContent: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if post.canBeDeleted {
            buttons.append(ActionSheet.Button.destructive(Text("Post.Delete.Button", bundle: .module)) {
                displayDeleteAlert = true
            })
        }
        if post.canBeModerated {
            buttons.append(ActionSheet.Button.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(post.uuid)
            })
        }

        buttons.append(.cancel())
        return buttons
    }

    var reactions: [ReactionCount] {
        switch post.content {
        case let .published(postContent): postContent.liveMeasuresValue.aggregatedInfo.reactions
        case .moderated: []
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

private struct PublishedContentView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore
    @EnvironmentObject private var videoManager: VideoManager
    @EnvironmentObject private var trackingApi: TrackingApi
    @EnvironmentObject private var urlOpener: URLOpener

    let content: DisplayablePost.PostContent
    let post: DisplayablePost
    let contentId: String
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let childrenTapped: () -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let commentReactionTapped: (ReactionKind?, String) -> Void
    let voteOnPoll: (String) -> Bool
    let displayClientObject: ((String) -> Void)?
    let displayPostDetail: (_ scrollTo: String?) -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (String) -> Void
    let deleteComment: (String) -> Void
    let displayContentModeration: (String) -> Void
    private let minAspectRatio: CGFloat = 4 / 5
    private let horizontalPadding: CGFloat = 16

    @State private var liveMeasures: LiveMeasures?

    var displayTranslation: Bool { translationStore.displayTranslation(for: contentId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { displayPostDetail(nil) }) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 8)
                    if let catchPhrase = content.bridgeInfo?.catchPhrase {
                        Text(catchPhrase.getText(translated: displayTranslation))
                            .font(theme.fonts.body2)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.gray900)
                        Spacer().frame(height: 4)
                    }
                    if content.text.getIsEllipsized(translated: displayTranslation) {
                        Text(verbatim: "\(content.text.getText(translated: displayTranslation))... ")
                        +
                        Text("Common.ReadMore", bundle: .module)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray500)
                    } else {
                        Text(content.text.getText(translated: displayTranslation))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .modify {
                    if !content.text.hasTranslation && content.attachment != nil {
                        $0.padding(.bottom, 4)
                    } else { $0 }
                }
                .contentShape(Rectangle())
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, horizontalPadding)
            .accessibilityElement(children: .combine)
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilityHintInBundle("Accessibility.Post.List.OpenDetail.Hint")
                } else { $0 }
            }

            if !hasPoll && content.text.hasTranslation {
                ToggleTextTranslationButton(contentId: contentId, originalLanguage: content.text.originalLanguage,
                                            contentKind: .post)
                    .padding(.horizontal, horizontalPadding)
            }

            switch content.attachment {
            case let .image(image):
                AsyncCachedImage(
                    url: image.url, cache: .content,
                    croppingRatio: minAspectRatio,
                    placeholder: {
                        theme.colors.gray200
                            .aspectRatio(
                                max(image.size.width/image.size.height, minAspectRatio),
                                contentMode: .fit)
                            .clipped()
                    },
                    content: { cachedImage in
                        Image(uiImage: cachedImage.ratioImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .modify {
                                if zoomableImageInfo?.url != image.url {
                                    $0.namespacedMatchedGeometryEffect(id: image.url, isSource: true)
                                } else {
                                    $0
                                }
                            }
                            .modify {
                                if #available(iOS 15.0, *) {
                                    // put the tap in an overlay because it seems that the image touch area is not
                                    // clipped. Hence, it takes the tap over the text. When put in an overlay, it seems
                                    // to work correctly
                                    $0.overlay {
                                        Color.white.opacity(0.0001)
                                            .onTapGesture {
                                                withAnimation {
                                                    zoomableImageInfo = .init(
                                                        url: image.url,
                                                        image: Image(uiImage: cachedImage.fullSizeImage),
                                                        transitionImage: Image(uiImage: cachedImage.ratioImage))
                                                }
                                            }
                                    }
                                } else {
                                    $0.onTapGesture {
                                        withAnimation {
                                            zoomableImageInfo = .init(
                                                url: image.url,
                                                image: Image(uiImage: cachedImage.fullSizeImage))
                                        }
                                    }
                                }
                            }
                    }
                )
                .modify {
                    if #unavailable(iOS 17.0) {
                        $0.fixedSize(horizontal: false, vertical: true)
                    } else { $0 }
                }
                .padding(.top, content.text.hasTranslation ? 0 : 4)
            case let .video(video):
                VideoPlayerView(
                    videoManager: videoManager,
                    videoMedia: video,
                    contentId: post.uuid,
                    width: width
                )
                .aspectRatio(video.size.width/video.size.height, contentMode: .fit)
                .padding(.top, content.text.hasTranslation ? 0 : 4)
                .anchorPreference(key: VisibleItemsPreference.self, value: .bounds, transform: { anchor in
                    [.init(item: post.toVisiblePost, bounds: anchor)]
                })
            case let .poll(poll):
                PollView(poll: poll,
                         aggregatedInfo: liveMeasures?.aggregatedInfo ?? content.liveMeasuresValue.aggregatedInfo,
                         userInteractions: liveMeasures?.userInteractions ?? content.liveMeasuresValue.userInteractions,
                         parentId: contentId,
                         vote: voteOnPoll)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 4)

                if content.text.hasTranslation {
                    ToggleTextTranslationButton(contentId: contentId, originalLanguage: content.text.originalLanguage,
                                                contentKind: .post)
                        .padding(.horizontal, horizontalPadding)
                }
            case .none:
                EmptyView()
            }

            if let bridgeInfo = content.bridgeInfo, let ctaText = bridgeInfo.ctaText, let displayClientObject {
                HStack {
                    Spacer()
                    Button(action: { displayClientObject(bridgeInfo.objectId) }) {
                        Text(ctaText.getText(translated: displayTranslation))
                            .lineLimit(1)
                    }
                    .buttonStyle(OctopusButtonStyle(.mid, externalTopPadding: 10))
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
            }

            if let customAction = content.customAction {
                HStack {
                    Spacer()
                    Button(action: {
                        trackingApi.trackPostCustomActionButtonHit(postId: post.uuid)
                        urlOpener.open(url: customAction.targetUrl)
                    }) {
                        Text(customAction.ctaText.getText(translated: displayTranslation))
                            .lineLimit(1)
                    }
                    .buttonStyle(OctopusButtonStyle(.mid, externalTopPadding: 10))
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
            }

            let aggregatedInfo = liveMeasures?.aggregatedInfo ?? content.liveMeasuresValue.aggregatedInfo
            if !aggregatedInfo.reactions.isEmpty || aggregatedInfo.childCount > 0 || aggregatedInfo.viewCount > 0  {
                PostAggregatedInfoView(
                    aggregatedInfo: aggregatedInfo,
                    childrenTapped: childrenTapped)
                .padding(.horizontal, horizontalPadding)
            } else {
                Color.clear.frame(height: 16)
            }


            AdaptiveAccessibleStack2Contents(
                hStackSpacing: 16,
                vStackSpacing: 0,
                horizontalContent: {
                    ReactionsPickerView(
                        contentId: contentId,
                        userReaction: liveMeasures?.userInteractions.reaction ?? content.liveMeasuresValue.userInteractions.reaction,
                        reactionTapped: reactionTapped)

                    Spacer()

                    if !UIAccessibility.isVoiceOverRunning {
                        Button(action: childrenTapped) {
                            CreateChildInteractionView(image: .AggregatedInfo.comment,
                                                       text: "Content.AggregatedInfo.Comment",
                                                       kind: .comment)
                        }
                        .buttonStyle(OctopusButtonStyle(.mid, style: .outline, externalVerticalPadding: 6))
                    }
                },
                verticalContent: {
                    ReactionsPickerView(
                        contentId: contentId,
                        userReaction: liveMeasures?.userInteractions.reaction ?? content.liveMeasuresValue.userInteractions.reaction,
                        reactionTapped: reactionTapped)

                    if !UIAccessibility.isVoiceOverRunning {
                        HStack(spacing: 0) {
                            Spacer()
                            Button(action: childrenTapped) {
                                CreateChildInteractionView(image: .AggregatedInfo.comment,
                                                           text: "Content.AggregatedInfo.Comment",
                                                           kind: .comment)
                            }
                            .buttonStyle(OctopusButtonStyle(.mid, style: .outline, externalVerticalPadding: 6))
                            Spacer()
                        }
                    }
                })
            .padding(.horizontal, horizontalPadding)

            if UIAccessibility.isVoiceOverRunning {
                HStack(spacing: 0) {
                    Spacer()
                    Button(action: childrenTapped) {
                        CreateChildInteractionView(image: .AggregatedInfo.comment,
                                                   text: "Content.AggregatedInfo.Comment",
                                                   kind: .comment)
                    }
                    .buttonStyle(OctopusButtonStyle(.mid, style: .outline, externalVerticalPadding: 6))
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
            }

            if let featuredComment = content.featuredComment {
                ResponseFeedItemView(
                    response: featuredComment,
                    displayChildCount: false,
                    tapToOpenDetail: true,
                    zoomableImageInfo: .constant(nil),
                    displayResponseDetail: displayCommentDetail,
                    displayParentDetail: displayPostDetail,
                    displayProfile: displayProfile,
                    deleteResponse: deleteComment,
                    reactionTapped: commentReactionTapped,
                    displayContentModeration: displayContentModeration
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .onReceive(content.liveMeasures) { newLiveMeasures in
            guard newLiveMeasures != liveMeasures else { return }
            withAnimation {
                liveMeasures = newLiveMeasures
            }
        }
    }

    var hasPoll: Bool {
        switch content.attachment {
        case .poll: return true
        default: return false
        }
    }
}

private struct ModeratedPostContentView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager
    let reasons: [DisplayableString]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 8)
            Text("Post.List.ModeratedPost.MainText", bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)

            Spacer().frame(height: 8)

            Text("Post.List.ModeratedPost.Reason_reasons:\(reasons.map { $0.localizedString(locale: languageManager.overridenLocale) }.joined(separator: ", "))", bundle: .module)
                .font(theme.fonts.caption1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

private struct OpenDetailButton<Content: View>: View {
    let post: DisplayablePost
    let displayPostDetail: (String) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: {
            if post.canBeOpened {
                displayPostDetail(post.uuid)
            }
        }) {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .preventScrollViewConflict()
    }
}

private extension View {
    /// This function prevent any tap conflict on a Button that can occurs when a Button is inside a ScrollView
    /// presented with a sheet on iOS 18.
    /// In that case, adding a simultaneous TapGesture seems to remove the bug.
    func preventScrollViewConflict() -> some View {
        self
            .modify {
                if #available(iOS 26, *) {
                    $0
                } else {
                    if #available(iOS 18, *) {
                        $0.simultaneousGesture(TapGesture())
                    } else {
                        $0
                    }
                }
            }
    }
}

import Combine
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
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
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
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
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
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
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
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
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
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
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "3d ago",
            topic: "Help",
            canBeDeleted: false,
            canBeModerated: true,
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
        zoomableImageInfo: .constant(nil),
        displayPostDetail: { _, _, _, _, _ in },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        deletePost: { _ in },
        deleteComment: { _ in },
        reactionTapped: { _, _ in },
        commentReactionTapped: { _, _ in },
        voteOnPoll: { _, _ in false },
        displayContentModeration: { _ in },
        displayClientObject: { _ in })
    .mockContentTranslationPreferenceStore()
}
