//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus
import OctopusCore

struct PostDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @EnvironmentObject var trackingApi: TrackingApi
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    @Compat.StateObject private var viewModel: PostDetailViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var showChangesWillBeLostAlert = false

    @State private var displayWillDeleteAlert = false
    @State private var displayPostDeletedAlert = false

    @State private var commentTextFocused: Bool
    @State private var commentHasChanges = false

    @State private var zoomableImageInfo: ZoomableImageInfo?

    @State private var width: CGFloat = 0

    private let canClose: Bool
    
    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         postUuid: String,
         comment: Bool,
         commentToScrollTo: String?,
         scrollToMostRecentComment: Bool = false,
         origin: PostDetailNavigationOrigin,
         hasFeaturedComment: Bool,
         canClose: Bool = false) {
        _viewModel = Compat.StateObject(wrappedValue: PostDetailViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
            postUuid: postUuid,
            commentToScrollTo: commentToScrollTo,
            scrollToMostRecentComment: scrollToMostRecentComment,
            origin: origin,
            hasFeaturedComment: hasFeaturedComment))
        _commentTextFocused = .init(initialValue: comment)
        self.canClose = canClose
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ContentView(
                    post: viewModel.post, comments: viewModel.comments,
                    hasMoreComments: viewModel.hasMoreData,
                    hideLoadMoreCommentsLoader: viewModel.hideLoadMoreCommentsLoader,
                    width: width,
                    scrollToBottom: $viewModel.scrollToBottom,
                    scrollToId: $viewModel.scrollToId,
                    zoomableImageInfo: $zoomableImageInfo,
                    loadPreviousComments: viewModel.loadPreviousComments,
                    refresh: viewModel.refresh,
                    displayCommentDetail: { commentId, reply in
                        navigator.push(.commentDetail(commentId: commentId, displayGoToParentButton: false,
                                                      reply: reply, replyToScrollTo: nil))
                    },
                    displayProfile: { profileId in
                        if profileId == viewModel.thisUserProfileId {
                            navigator.push(.currentUserProfile)
                        } else {
                            navigator.push(.publicProfile(profileId: profileId))
                        }
                    },
                    openCreateComment: {
                        trackingApi.emit(event: .commentButtonClicked(.init(postId: viewModel.postUuid)))
                        commentTextFocused = true
                    },
                    deletePost: viewModel.deletePost,
                    deleteComment: viewModel.deleteComment,
                    reactionTapped: viewModel.setReaction(_:),
                    voteOnPoll: viewModel.vote,
                    commentReactionTapped: viewModel.setCommentReaction(_:commentId:),
                    displayContentModeration: {
                        guard viewModel.ensureConnected(action: .moderation) else { return }
                        navigator.push(.reportContent(contentId: $0))
                    },
                    displayClientObject: (viewModel.canDisplayClientObject ? { viewModel.displayClientObject(clientObjectId:$0) } : nil)
                )
                .toastContainer(octopus: viewModel.octopus)

                CreateCommentView(octopus: viewModel.octopus, postId: viewModel.postUuid,
                                  translationStore: translationStore,
                                  textFocused: $commentTextFocused,
                                  hasChanges: $commentHasChanges,
                                  ensureConnected: viewModel.ensureConnected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.postDeletion == .inProgress || viewModel.isDeletingComment {
                Compat.ProgressView()
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerSize: CGSize(width: 4, height: 4))
                            .modify {
                                if #available(iOS 15.0, *) {
                                    $0.fill(.thickMaterial)
                                } else {
                                    $0.fill(theme.colors.gray200)
                                }
                            }
                    )
            }
        }
        .readWidth($width)
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarTitle: Text(viewModel.post?.topic ?? ""),
                                defaultNavigationBarBackButtonHidden: commentHasChanges)
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
        .onReceive(viewModel.$postDeletion) { postDeletion in
            if postDeletion == .done {
                displayPostDeletedAlert = true
            }
        }
        .onAppear() {
            viewModel.onAppear()
        }
        .emitScreenDisplayed(.postDetail(.init(postId: viewModel.postUuid)), trackingApi: trackingApi)
        .onDisappear() {
            viewModel.onDisappear()
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Common.CancelModifications", bundle: .module),
                    isPresented: $showChangesWillBeLostAlert) {
                        Button(role: .cancel, action: {}) { Text("Common.No", bundle: .module) }
                        Button(role: .destructive, action: {
                            if canClose {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                navigator.pop()
                            }
                        }) { Text("Common.Yes", bundle: .module) }
                    }
            } else {
                $0.alert(isPresented: $showChangesWillBeLostAlert) {
                    Alert(title: Text("Common.CancelModifications", bundle: .module),
                          primaryButton: .default(Text("Common.No", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Yes", bundle: .module),
                            action: {
                                if canClose {
                                    presentationMode.wrappedValue.dismiss()
                                } else {
                                    navigator.pop()
                                }
                            }
                          )
                    )
                }
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Done", bundle: .module),
                    isPresented: $displayPostDeletedAlert, actions: {
                        Button(action: { navigator.pop() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $displayPostDeletedAlert) {
                    Alert(title: Text("Post.Delete.Done", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        navigator.pop()
                    }))
                }
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Comment.Delete.Done", bundle: .module),
                    isPresented: $viewModel.commentDeleted, actions: { })
            } else {
                $0.alert(isPresented: $viewModel.commentDeleted) {
                    Alert(title: Text("Comment.Delete.Done", bundle: .module))
                }
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Content.Detail.NotAvailable", bundle: .module),
                    isPresented: $viewModel.postNotAvailable, actions: {
                        Button(action: { navigator.pop() }) {
                            Text("Common.Ok", bundle: .module)
                        }

                    })
            } else {
                $0.alert(isPresented: $viewModel.postNotAvailable) {
                    Alert(title: Text("Content.Detail.NotAvailable", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        navigator.pop()
                    }))
                }
            }
        }
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if canClose {
            // Do not display the back button
            Color.white.opacity(0.0001)
        } else
        if commentHasChanges {
            BackButton(action: { showChangesWillBeLostAlert = true })
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        if canClose {
            Button(action: {
                if commentHasChanges {
                    showChangesWillBeLostAlert = true
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Text("Common.Close", bundle: .module)
                    .font(theme.fonts.navBarItem)
            }
        } else {
            EmptyView()
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    let post: PostDetailViewModel.Post?
    let comments: [DisplayableFeedResponse]?
    let hasMoreComments: Bool
    let hideLoadMoreCommentsLoader: Bool
    let width: CGFloat
    @Binding var scrollToBottom: Bool
    @Binding var scrollToId: String?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousComments: () -> Void
    let refresh: @Sendable () async -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let deleteComment: (String) -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let voteOnPoll: (String) -> Bool
    let commentReactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
#if compiler(>=6.2)
            // Disable nav bar opacity on iOS 26 to have the same behavior as before.
            // TODO: See with product team if we need to keep it.
            if #available(iOS 26.0, *) {
                Color.white.opacity(0.0001)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
#endif
            Compat.ScrollView(scrollToBottom: $scrollToBottom, scrollToId: $scrollToId, idAnchor: .bottom,
                              refreshAction: refresh) {
                Compat.LazyVStack(spacing: 0) {
                    if let post {
                        PostDetailContentView(post: post,
                                              width: width,
                                              zoomableImageInfo: $zoomableImageInfo,
                                              displayProfile: displayProfile,
                                              openCreateComment: openCreateComment,
                                              deletePost: deletePost,
                                              reactionTapped: reactionTapped,
                                              voteOnPoll: voteOnPoll,
                                              displayContentModeration: displayContentModeration,
                                              displayClientObject: displayClientObject)

                        Spacer().frame(height: 14)
                        theme.colors.gray300.frame(height: 1)
                        Spacer().frame(height: 10)

                        if let comments {
                            CommentsView(comments: comments,
                                         hasMoreData: hasMoreComments,
                                         hideLoader: hideLoadMoreCommentsLoader,
                                         zoomableImageInfo: $zoomableImageInfo,
                                         loadPreviousComments: loadPreviousComments,
                                         displayCommentDetail: displayCommentDetail,
                                         displayProfile: displayProfile,
                                         openCreateComment: openCreateComment,
                                         deleteComment: deleteComment,
                                         reactionTapped: commentReactionTapped,
                                         displayContentModeration: displayContentModeration)
                            .padding(.leading, 10)
                            .padding(.trailing, 16)
                        } else {
                            Compat.ProgressView()
                        }
                    } else {
                        VStack {
                            Spacer().frame(height: 54)
                            Image(res: .contentNotAvailable)
                            Text("Content.Detail.NotAvailable", bundle: .module)
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(theme.colors.gray500)
                    }
                }
            }.postsVisibilityScrollView()
        }
    }
}

private struct PostDetailContentView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore
    @EnvironmentObject private var videoManager: VideoManager
    @EnvironmentObject private var trackingApi: TrackingApi
    @EnvironmentObject private var urlOpener: URLOpener

    let post: PostDetailViewModel.Post
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let voteOnPoll: (String) -> Bool
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    @State private var displayWillDeleteAlert = false
    @State private var openActions = false

    private let horizontalPadding = CGFloat(16)
    private let minAspectRatio: CGFloat = 4 / 5

    @Compat.ScaledMetric(relativeTo: .subheadline) var moreIconSize: CGFloat = 24 // subheadline to vary from 19 to 69
    @Compat.ScaledMetric(relativeTo: .title1) var authorAvatarSize: CGFloat = 40 // title1 to vary from 40 to 88

    var displayTranslation: Bool { translationStore.displayTranslation(for: post.uuid) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Group { // group views to have the same horizontal padding
                    HStack(alignment: .top, spacing: 0) {
                        let topPadding = CGFloat(21)
                        OpenProfileButton(author: post.author, displayProfile: displayProfile) {
                            AuthorAvatarView(avatar: post.author.avatar)
                                .frame(width: max(authorAvatarSize, 40), height: max(authorAvatarSize, 40))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        }
                        .frame(width: max(authorAvatarSize, 44), height: max(authorAvatarSize, 44))
                        .padding(.top, topPadding)

                        Spacer().frame(width: 3)

                        VStack(alignment: .leading, spacing: 0) {
                            AuthorAndDateHeaderView(author: post.author, relativeDate: post.relativeDate,
                                                    topPadding: topPadding, bottomPadding: 4,
                                                    displayProfile: displayProfile)
                            Text(post.topic)
                                .octopusBadgeStyle(.small, status: .off)
                        }
                        Spacer()

                        if post.canBeDeleted || post.canBeModerated {
                            if #available(iOS 14.0, *) {
                                Menu(content: {
                                    if post.canBeDeleted {
                                        Button(action: { displayWillDeleteAlert = true }) {
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
                                .padding(.top, topPadding)
                            } else {
                                Button(action: { openActions = true }) {
                                    Image(res: .more)
                                        .resizable()
                                        .frame(width: max(moreIconSize, 24), height: max(moreIconSize, 24))
                                        .foregroundColor(theme.colors.gray500)
                                        .accessibilityLabelInBundle("Accessibility.Common.More")
                                }
                                .buttonStyle(.plain)
                                .padding(.top, topPadding)
                            }
                        }
                    }

                    Spacer().frame(height: 8)

                    if let catchPhrase = post.catchPhrase {
                        Text(catchPhrase.getText(translated: displayTranslation))
                            .font(theme.fonts.body2)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.gray900)
                        Spacer().frame(height: 4)
                    }
                    RichText(post.text.getText(translated: displayTranslation))
                        .font(theme.fonts.body2)
                        .lineSpacing(4)
                        .foregroundColor(theme.colors.gray900)
                        .fixedSize(horizontal: false, vertical: true)

                    if !hasPoll && post.text.hasTranslation {
                        ToggleTextTranslationButton(
                            contentId: post.uuid, originalLanguage: post.text.originalLanguage,
                            contentKind: .post)
                    }
                }.padding(.horizontal, horizontalPadding)
                switch post.attachment {
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
                                .modify {
                                    if zoomableImageInfo?.url != image.url {
                                        $0.namespacedMatchedGeometryEffect(id: image.url, isSource: true)
                                    } else {
                                        $0
                                    }
                                }
                                .onTapGesture {
                                    withAnimation {
                                        zoomableImageInfo = .init(
                                            url: image.url,
                                            image: Image(uiImage: cachedImage.fullSizeImage))
                                    }
                                }
                        })
                    .frame(maxWidth: .infinity)
                    .modify {
                        if #unavailable(iOS 17.0) {
                            $0.fixedSize(horizontal: false, vertical: true)
                        } else { $0 }
                    }
                    .padding(.top, post.text.hasTranslation ? 4 : 8)
                case let .video(video):
                    VideoPlayerView(
                        videoManager: videoManager,
                        videoMedia: video,
                        contentId: post.uuid,
                        width: width
                    )
                    .aspectRatio(video.size.width/video.size.height, contentMode: .fit)
                    .anchorPreference(key: VisibleItemsPreference.self, value: .bounds, transform: { anchor in
                        [.init(item: post.toVisiblePost, bounds: anchor)]
                    })
                    .padding(.top, post.text.hasTranslation ? 4 : 8)
                case let .poll(poll):
                    PollView(poll: poll,
                             aggregatedInfo: post.aggregatedInfo,
                             userInteractions: post.userInteractions,
                             parentId: post.uuid,
                             vote: voteOnPoll)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, post.text.hasTranslation ? 4 : 8)

                    if post.text.hasTranslation {
                        ToggleTextTranslationButton(contentId: post.uuid, originalLanguage: post.text.originalLanguage,
                                                    contentKind: .post)
                            .padding(.horizontal, horizontalPadding)
                    }
                case .none:
                    EmptyView()
                }

                if let bridgeCTA = post.bridgeCTA, let displayClientObject {
                    HStack {
                        Spacer()
                        Button(action: { displayClientObject(bridgeCTA.clientObjectId) }) {
                            Text(bridgeCTA.text.getText(translated: displayTranslation))
                                .lineLimit(1)
                        }
                        .buttonStyle(OctopusButtonStyle(.mid))
                        Spacer()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                }

                if let customAction = post.customAction {
                    HStack {
                        Spacer()
                        Button(action: {
                            trackingApi.trackPostCustomActionButtonHit(postId: post.uuid)
                            urlOpener.open(url: customAction.targetUrl)
                        }) {
                            Text(customAction.ctaText.getText(translated: displayTranslation))
                                .lineLimit(1)
                        }
                        .buttonStyle(OctopusButtonStyle(.mid))
                        Spacer()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                }

                let aggregatedInfo = post.aggregatedInfo
                if !aggregatedInfo.reactions.isEmpty || aggregatedInfo.childCount > 0 || aggregatedInfo.viewCount > 0  {
                    PostAggregatedInfoView(
                        aggregatedInfo: aggregatedInfo,
                        childrenTapped: openCreateComment)
                    .padding(.horizontal, horizontalPadding)
                } else {
                    Color.clear.frame(height: 16)
                }

                AdaptiveAccessibleStack2Contents(
                    hStackSpacing: 16,
                    vStackSpacing: 0,
                    horizontalContent: {
                        ReactionsPickerView(
                            contentId: post.uuid,
                            userReaction: post.userInteractions.reaction,
                            reactionTapped: reactionTapped)

                        Spacer()

                        if !UIAccessibility.isVoiceOverRunning {
                            Button(action: openCreateComment) {
                                CreateChildInteractionView(image: .AggregatedInfo.comment,
                                                           text: "Content.AggregatedInfo.Comment",
                                                           kind: .comment)
                            }
                            .buttonStyle(OctopusButtonStyle(.mid, style: .outline, externalVerticalPadding: 6))
                        }
                    },
                    verticalContent: {
                        ReactionsPickerView(
                            contentId: post.uuid,
                            userReaction: post.userInteractions.reaction,
                            reactionTapped: reactionTapped)

                        if !UIAccessibility.isVoiceOverRunning {
                            HStack(spacing: 0) {
                                Spacer()
                                Button(action: openCreateComment) {
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
                        Button(action: openCreateComment) {
                            CreateChildInteractionView(image: .AggregatedInfo.comment,
                                                       text: "Content.AggregatedInfo.Comment",
                                                       kind: .comment)
                        }
                        .buttonStyle(OctopusButtonStyle(.mid, style: .outline, externalVerticalPadding: 6))
                        Spacer()
                    }
                    .padding(.horizontal, horizontalPadding)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: actionSheetContent)
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Confirmation.Title", bundle: .module),
                    isPresented: $displayWillDeleteAlert) {
                        Button(role: .cancel, action: {}, label: { Text("Common.Cancel", bundle: .module) })
                        Button(role: .destructive, action: { deletePost() },
                               label: { Text("Common.Delete", bundle: .module) })
                    }
            } else {
                $0.alert(isPresented: $displayWillDeleteAlert) {
                    Alert(title: Text("Post.Delete.Confirmation.Title",
                                      bundle: .module),
                          primaryButton: .default(Text("Common.Cancel", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Delete", bundle: .module),
                            action: { deletePost() }
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
                displayWillDeleteAlert = true
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

    var hasPoll: Bool {
        switch post.attachment {
        case .poll: return true
        default: return false
        }
    }

}

private struct CommentsView: View {
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
    let reactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        if !comments.isEmpty {
            Compat.LazyVStack(spacing: 0) {
                ForEach(comments, id: \.uuid) { comment in
                    ResponseFeedItemView(
                        response: comment,
                        zoomableImageInfo: $zoomableImageInfo,
                        displayResponseDetail: displayCommentDetail, displayParentDetail: { _ in },
                        displayProfile: displayProfile, deleteResponse: deleteComment,
                        reactionTapped: reactionTapped,
                        displayContentModeration: displayContentModeration)
                    .onAppear {
                        comment.displayEvents.onAppear()
                    }
                    .onDisappear() {
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
            }
        } else {
            Button(action: openCreateComment) {
                VStack {
                    Spacer().frame(height: 54)
                    Image(res: .contentNotAvailable)
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

#Preview("Text only") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text"),
            attachment: nil,
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
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        comments: [],
        hasMoreComments: true,
        hideLoadMoreCommentsLoader: false,
        width: 375,
        scrollToBottom: .constant(false),
        scrollToId: .constant(nil),
        zoomableImageInfo: .constant(nil),
        loadPreviousComments: { },
        refresh: { },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockContentTranslationPreferenceStore()
}

#Preview("Text and Image") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text"),
            attachment: .image(.init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750))),
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
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        comments: [],
        hasMoreComments: true,
        hideLoadMoreCommentsLoader: false,
        width: 375,
        scrollToBottom: .constant(false),
        scrollToId: .constant(nil),
        zoomableImageInfo: .constant(nil),
        loadPreviousComments: { },
        refresh: { },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockContentTranslationPreferenceStore()
}

#Preview("Text and Poll") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text"),
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
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        comments: [],
        hasMoreComments: true,
        hideLoadMoreCommentsLoader: false,
        width: 375,
        scrollToBottom: .constant(false),
        scrollToId: .constant(nil),
        zoomableImageInfo: .constant(nil),
        loadPreviousComments: { },
        refresh: { },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockContentTranslationPreferenceStore()
}

#Preview("Text no translation") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: nil),
            attachment: .poll(
                DisplayablePoll(options: [
                    .init(id: "1", text: .init(
                        originalText: "Option 1",
                        originalLanguage: nil)),
                    .init(id: "2", text: .init(
                        originalText: "Option 2",
                        originalLanguage: nil))
                ])
            ),
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
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        comments: [],
        hasMoreComments: true,
        hideLoadMoreCommentsLoader: false,
        width: 375,
        scrollToBottom: .constant(false),
        scrollToId: .constant(nil),
        zoomableImageInfo: .constant(nil),
        loadPreviousComments: { },
        refresh: { },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockContentTranslationPreferenceStore()
}

#Preview("Bridge Text and Image") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text"),
            attachment: .image(.init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750))),
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
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            catchPhrase: .init(
                originalText: "Qu'en pensez vous ?",
                originalLanguage: "fr",
                translatedText: "What do you think?"),
            bridgeCTA: nil,
            customAction: nil
        ),
        comments: [],
        hasMoreComments: true,
        hideLoadMoreCommentsLoader: false,
        width: 375,
        scrollToBottom: .constant(false),
        scrollToId: .constant(nil),
        zoomableImageInfo: .constant(nil),
        loadPreviousComments: { },
        refresh: { },
        displayCommentDetail: { _, _ in },
        displayProfile: { _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockContentTranslationPreferenceStore()
}
