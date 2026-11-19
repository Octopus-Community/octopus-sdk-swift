//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus
import OctopusCore

struct PostDetailView: View {
    @Environment(\.textTone) private var textTone
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.trackingApi) var trackingApi
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore
    @EnvironmentObject private var languageManager: LanguageManager

    @Compat.StateObject private var viewModel: PostDetailViewModel

    @State private var showChangesWillBeLostAlert = false

    @State private var displayWillDeleteAlert = false
    @State private var displayWillBlockAlert = false
    @State private var displayPostDeletedAlert = false

    @State private var commentHasChanges = false

    @State private var zoomableImageInfo: ZoomableImageInfo?

    @State private var width: CGFloat = 0

    private let canClose: Bool
    private let mainFlowPath: MainFlowPath
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         postUuid: String,
         comment: Bool,
         commentToScrollTo: String?,
         scrollToMostRecentComment: Bool = false,
         origin: PostDetailNavigationOrigin,
         hasFeaturedComment: Bool,
         canClose: Bool = false,
         navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: PostDetailViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
            postUuid: postUuid,
            commentToScrollTo: commentToScrollTo,
            scrollToMostRecentComment: scrollToMostRecentComment,
            comment: comment,
            origin: origin,
            hasFeaturedComment: hasFeaturedComment))
        self.canClose = canClose
        self.mainFlowPath = mainFlowPath
        self.navBarLeadingAction = navBarLeadingAction
    }

    /// Leaves the post detail: runs the host leading action when provided, otherwise dismisses a native
    /// presentation (`canClose`) or pops the SDK navigation stack.
    private func leaveScreen() {
        if let navBarLeadingAction {
            navBarLeadingAction.onTap()
        } else if canClose {
            presentationMode.wrappedValue.dismiss()
        } else {
            navigator.pop()
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ContentView(
                    post: viewModel.post, postNotAvailable: viewModel.postNotAvailable,
                    lockedState: viewModel.lockedState,
                    comments: viewModel.comments,
                    commentsLoadFailure: viewModel.commentsLoadFailure,
                    contentLoadFailure: viewModel.contentLoadFailure,
                    retryFirstLoad: viewModel.retryFirstLoad,
                    hasLoadedComments: viewModel.hasLoadedComments,
                    retryCommentsFirstLoad: viewModel.retryCommentsFirstLoad,
                    hasMoreComments: viewModel.hasMoreData,
                    hideLoadMoreCommentsLoader: viewModel.hideLoadMoreCommentsLoader,
                    listsMostRecentEnd: viewModel.listsMostRecentEnd,
                    hasNewerComments: viewModel.hasNewerComments,
                    listedWindowId: viewModel.listedWindowId,
                    hidesUntilLanded: viewModel.hidesListUntilLanded,
                    landsWithoutAnimation: viewModel.landsWithoutAnimation,
                    width: width,
                    scrollToBottom: $viewModel.scrollToBottom,
                    scrollToId: $viewModel.scrollToId,
                    scrollRequest: $viewModel.scrollRequest,
                    listsDownToScrollTarget: viewModel.listsDownToTargetComment,
                    zoomableImageInfo: $zoomableImageInfo,
                    loadPreviousComments: viewModel.loadPreviousComments,
                    previousCommentsLoaderDisappeared: viewModel.previousCommentsLoaderDisappeared,
                    loadNewerComments: viewModel.loadNewerComments,
                    newerCommentsLoaderDisappeared: viewModel.newerCommentsLoaderDisappeared,
                    newestCommentOnScreenChanged: viewModel.newestCommentOnScreenChanged,
                    refresh: viewModel.refresh,
                    displayCommentDetail: { commentId, reply in
                        navigator.push(.commentDetail(commentId: commentId, displayGoToParentButton: false,
                                                      reply: reply, replyToScrollTo: nil))
                    },
                    displayProfile: { profileId, clientUserId in
                        dispatchProfileTap(octopus: viewModel.octopus, navigator: navigator,
                                           profileId: profileId, clientUserId: clientUserId)
                    },
                    openCreateComment: {
                        trackingApi.emit(event: .commentButtonClicked(.init(postId: viewModel.postUuid)))
                        viewModel.commentTextFocused = true
                    },
                    deletePost: viewModel.deletePost,
                    deleteComment: viewModel.deleteComment,
                    blockAuthor: viewModel.blockAuthor(profileId:),
                    reactionTapped: viewModel.setReaction(_:),
                    voteOnPoll: viewModel.vote,
                    commentReactionTapped: viewModel.setCommentReaction(_:commentId:),
                    displayContentModeration: {
                        guard viewModel.ensureConnected(action: .moderation) else { return }
                        mainFlowPath.reportTarget = $0
                    },
                    displayClientObject: (viewModel.canDisplayClientObject ? { viewModel.displayClientObject(clientObjectId: $0) } : nil),
                    openGroup: { navigator.push(.groupDetail(groupId: $0)) }
                )
                .toastContainer(octopus: viewModel.octopus,
                                retryFailedFetch: { Task { await viewModel.refresh() } })

                if viewModel.lockedState == .unlocked {
                    CreateCommentView(octopus: viewModel.octopus, postId: viewModel.postUuid,
                                      translationStore: translationStore,
                                      textFocused: $viewModel.commentTextFocused,
                                      hasChanges: $commentHasChanges,
                                      ensureConnected: viewModel.ensureConnected,
                                      nicknameChoiceClosed: viewModel.nicknameChoiceClosedPublisher)
                    // Opaque background extended into the bottom safe area so the composer bar and
                    // the home-indicator area stay white. On large screens (where side margins
                    // appear) the top is rounded (radius 24) so the gray margin background follows
                    // the bar's rounded top curve; on narrow screens (e.g. iPhone portrait, no
                    // margins) it stays square so no gray shows behind the corners.
                    .background(
                        theme.colors.background
                            .cornerRadius(width > OctopusContentLayout.maxContentWidth ? 24 : 0,
                                          corners: [.topLeft, .topRight])
                            .edgesIgnoringSafeArea(.bottom)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .largeScreenMarginBackground()

            if viewModel.postDeletion == .inProgress || viewModel.isDeletingComment {
                LoadingOverlay()
            }
        }
        .readWidth($width)
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction,
                          onNicknameChoiceClosed: viewModel.nicknameChoiceClosed)
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarTitle: title,
                                defaultNavigationBarBackButtonHidden: commentHasChanges)
        .errorAlert(viewModel.$error)
        .onReceive(viewModel.$postDeletion) { postDeletion in
            if postDeletion == .done {
                displayPostDeletedAlert = true
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .emitScreenDisplayed(.postDetail(.init(postId: viewModel.postUuid)), trackingApi: trackingApi)
        .onDisappear {
            viewModel.onDisappear()
        }
        .destructiveConfirmationAlert(
            textTone.key(formal: "Common.CancelModifications.Formal", informal: "Common.CancelModifications.Informal"),
            isPresented: $showChangesWillBeLostAlert,
            cancelLabel: "Common.No",
            destructiveLabel: "Common.Yes",
            action: { leaveScreen() })
        .destructiveConfirmationAlert(
            "Block.Profile.Alert.Title",
            isPresented: $displayWillBlockAlert,
            destructiveLabel: "Common.Continue",
            action: {
                if let profileId = viewModel.post?.author.profileId {
                    viewModel.blockAuthor(profileId: profileId)
                }
            },
            message: textTone.key(formal: "Block.Profile.Alert.Message.Formal",
                                  informal: "Block.Profile.Alert.Message.Informal"))
        .destructiveConfirmationAlert(
            textTone.key(formal: "Post.Delete.Confirmation.Title.Formal",
                         informal: "Post.Delete.Confirmation.Title.Informal"),
            isPresented: $displayWillDeleteAlert,
            destructiveLabel: "Common.Delete",
            action: { viewModel.deletePost() })
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Done", bundle: .module),
                    isPresented: $displayPostDeletedAlert, actions: {
                        Button(action: { leaveScreen() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $displayPostDeletedAlert) {
                    Alert(title: Text("Post.Delete.Done", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: { leaveScreen() }))
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
                    isPresented: $viewModel.postDisappeared, actions: {
                        Button(action: { leaveScreen() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $viewModel.postDisappeared) {
                    Alert(title: Text("Content.Detail.NotAvailable", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: { leaveScreen() }))
                }
            }
        }
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if let navBarLeadingAction {
            NavBarLeadingActionButton(navBarLeadingAction, onTap: {
                if commentHasChanges {
                    showChangesWillBeLostAlert = true
                } else {
                    navBarLeadingAction.onTap()
                }
            })
        } else if canClose {
            CloseButton(action: {
                if commentHasChanges {
                    showChangesWillBeLostAlert = true
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            })
        } else if commentHasChanges {
            BackButton(action: { showChangesWillBeLostAlert = true })
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        moreActionBarItem
    }

    @ViewBuilder
    private var moreActionBarItem: some View {
        if #available(iOS 14.0, *), let post = viewModel.post,
           post.canBeDeleted || post.canBeModerated || post.canBeBlockedByUser || post.groupId != nil {
            Menu(content: {
                if let groupId = post.groupId {
                    NeutralMenuButton(action: { navigator.push(.groupDetail(groupId: groupId)) }) {
                        Label(title: { Text("Post.Menu.ViewGroup.Button", bundle: .module) },
                              icon: { Image(uiImage: theme.assets.icons.groups.viewGroup) })
                    }
                }
                if post.canBeDeleted {
                    DestructiveMenuButton(action: { displayWillDeleteAlert = true }) {
                        Label(title: { Text("Post.Delete.Button", bundle: .module) },
                              icon: { Image(uiImage: theme.assets.icons.content.delete) })
                    }
                }
                if post.canBeModerated {
                    DestructiveMenuButton(action: {
                        guard viewModel.ensureConnected(action: .moderation) else { return }
                        mainFlowPath.reportTarget = .content(
                            contentId: post.uuid, author: post.author, authorCanBeBlocked: post.canBeBlockedByUser)
                    }) {
                        Label(title: { Text("Moderation.Content.Button", bundle: .module) },
                              icon: { Image(uiImage: theme.assets.icons.content.report) })
                    }
                }
                if post.canBeBlockedByUser {
                    DestructiveMenuButton(action: {
                        guard viewModel.ensureConnected(action: .blockUser) else { return }
                        displayWillBlockAlert = true
                    }) {
                        Label(title: { Text("Block.Profile.Button", bundle: .module) },
                              icon: { Image(uiImage: theme.assets.icons.profile.blockUser) })
                    }
                }
            }, label: {
                if GlassEffect.isAvailable {
                    Label(title: { Text("Accessibility.Common.More", bundle: .module) },
                          icon: { Image(uiImage: theme.assets.icons.common.moreActions) })
                } else {
                    Image(uiImage: theme.assets.icons.common.moreActions)
                        .font(theme.fonts.navBarItem)
                        .padding(.vertical)
                        .padding(.leading)
                        .frame(minWidth: 44, minHeight: 44)
                }
            })
            .buttonStyle(.plain)
        } else {
            EmptyView()
        }
    }

    private var title: Text {
        if let authorName = viewModel.postAuthorName {
            Text("Post.Title_author:\(authorName.localizedString(locale: languageManager.overridenLocale, tone: textTone))",
                 bundle: .module)
        } else {
            Text(verbatim: "")
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    let post: PostDetailViewModel.Post?
    let postNotAvailable: Bool
    let lockedState: LockedContentState
    let comments: [DisplayableFeedResponse]?
    var commentsLoadFailure: ScreenStateFailure?
    var contentLoadFailure: ScreenStateFailure?
    var retryFirstLoad: () -> Void = {}
    var hasLoadedComments = false
    var retryCommentsFirstLoad: () -> Void = {}
    let hasMoreComments: Bool
    let hideLoadMoreCommentsLoader: Bool
    /// Whether the comments are the most recent end of the thread, paging toward older ones from their top.
    var listsMostRecentEnd = false
    /// Whether newer comments are still to load below the window the screen opened on.
    var hasNewerComments = false
    /// The window of the thread the comments come from, `nil` when they are listed oldest first.
    var listedWindowId: String?
    /// Whether the list is hidden, a spinner in its place, until it landed on the most recent end.
    var hidesUntilLanded = false
    /// Whether the scroll to the bottom is not animated, while the list lands on its most recent end.
    var landsWithoutAnimation = false
    let width: CGFloat
    @Binding var scrollToBottom: Bool
    @Binding var scrollToId: String?
    var scrollRequest: Binding<Compat.ScrollRequest?> = .constant(nil)
    /// Whether the comments are listed from the first one down to the one the screen opened on: the list is then laid
    /// out whole, so the scroll to that comment finds its row.
    var listsDownToScrollTarget = false
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousComments: () -> Void
    var previousCommentsLoaderDisappeared: () -> Void = {}
    var loadNewerComments: () -> Void = {}
    var newerCommentsLoaderDisappeared: () -> Void = {}
    var newestCommentOnScreenChanged: (Bool) -> Void = { _ in }
    let refresh: @Sendable () async -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let deleteComment: (String) -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let voteOnPoll: (String) async -> Bool
    let commentReactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (ReportTarget) -> Void
    let displayClientObject: ((String) -> Void)?
    /// Opens a group, from the post's group name when the community makes it open the group.
    var openGroup: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
#if compiler(>=6.2)
            // When the glass effect is available, the navigation bar uses its default translucent (glass) behavior.
            // The near-invisible top spacer is kept only for pre-iOS-16 scroll behavior.
            if #unavailable(iOS 16.0) {
                Color.white.opacity(0.0001)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
#endif
            Compat.ScrollView(scrollToBottom: $scrollToBottom, scrollToId: $scrollToId, idAnchor: .bottom,
                              scrollRequest: scrollRequest, animatesScrollToBottom: !landsWithoutAnimation,
                              refreshAction: refresh) {
                // A window of the thread stays lazy, whether the most recent end or the one around the comment the
                // screen opened on: its comments lay out the part of the window the screen scrolls to at once (see
                // `MostRecentWindow.laidOutStart`). The whole list is laid out at once when it lists every comment
                // down to the one the screen opened on, or scrolls through them listed oldest first.
                LazyIfPossibleVStack(
                    spacing: 0,
                    preventLaziness: listsDownToScrollTarget
                        || !listsMostRecentEnd && (scrollToBottom || scrollToId != nil)) {
                    if let post {
                        PostDetailContentView(post: post,
                                              // Clamp to the content cap so media is sized to the
                                              // constrained column width, not the full screen.
                                              width: min(width, OctopusContentLayout.maxContentWidth),
                                              zoomableImageInfo: $zoomableImageInfo,
                                              displayProfile: displayProfile,
                                              openCreateComment: openCreateComment,
                                              deletePost: deletePost,
                                              blockAuthor: blockAuthor,
                                              reactionTapped: reactionTapped,
                                              voteOnPoll: voteOnPoll,
                                              displayContentModeration: displayContentModeration,
                                              displayClientObject: displayClientObject,
                                              openGroup: openGroup)

                        theme.colors.gray300.frame(height: 2)
                        Spacer().frame(height: 10)

                        if lockedState != .lockedOwnContent {
                            switch contentAreaState(itemCount: comments?.count,
                                                    hasLoadedOnce: hasLoadedComments,
                                                    loadFailure: commentsLoadFailure) {
                            case let .failure(commentsLoadFailure):
                                commentsLoadFailure.screenState(verticalPadding: ScreenState.postErrorPadding,
                                                               icons: theme.assets.icons,
                                                               retry: retryCommentsFirstLoad)
                            case .loader:
                                Compat.ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ScreenState.postEmptyPadding)
                            // The list view renders the empty state itself, so both share a branch.
                            case .empty, .content:
                                PostDetailCommentsView(comments: comments ?? [],
                                             hasMoreData: hasMoreComments,
                                             hideLoader: hideLoadMoreCommentsLoader,
                                             listsMostRecentEnd: listsMostRecentEnd,
                                             hasNewerData: hasNewerComments,
                                             windowId: listedWindowId,
                                             zoomableImageInfo: $zoomableImageInfo,
                                             loadPreviousComments: loadPreviousComments,
                                             displayCommentDetail: displayCommentDetail,
                                             displayProfile: displayProfile,
                                             openCreateComment: openCreateComment,
                                             deleteComment: deleteComment,
                                             blockAuthor: blockAuthor,
                                             reactionTapped: commentReactionTapped,
                                             displayContentModeration: displayContentModeration)
                                // No outer horizontal padding here: each row renders through
                                // `ResponseView`, which applies `.padding(.horizontal, 16)` itself.
                                // Adding an outer inset on top of that doubles the padding (10+16
                                // leading, 16+16 trailing = 32 on the right).
                            }
                        }
                    } else if postNotAvailable {
                        VStack {
                            Spacer().frame(height: 54)
                            Image(uiImage: theme.assets.icons.content.post.notAvailable)
                                .accessibilityHidden(true)
                            Text("Content.Detail.NotAvailable", bundle: .module)
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(theme.colors.gray500)
                    } else if let contentLoadFailure {
                        contentLoadFailure.screenState(verticalPadding: ScreenState.postErrorPadding,
                                                       icons: theme.assets.icons,
                                                       retry: retryFirstLoad)
                    } else {
                        VStack {
                            Spacer()
                            Compat.ProgressView()
                            Spacer()
                        }
                    }
                }
                .constrainedContentColumn()
            }
            .onTrackedViewOnScreenChanged { onScreen in
                // The loader of older comments, at the top of the most recent end.
                if onScreen {
                    if #available(iOS 14, *) { Logger.posts.trace("Top loader on screen, loading older items...") }
                    loadPreviousComments()
                } else {
                    previousCommentsLoaderDisappeared()
                }
            }
            .onTrackedViewOnScreenChanged(of: .newerItemsLoader) { onScreen in
                // The loader of newer comments, below the window the screen opened on.
                if onScreen {
                    if #available(iOS 14, *) { Logger.posts.trace("Bottom loader on screen, loading newer items...") }
                    loadNewerComments()
                } else {
                    newerCommentsLoaderDisappeared()
                }
            }
            // The newest comment of the most recent end, at the bottom of its window.
            .onTrackedViewOnScreenChanged(of: .newestItem, perform: newestCommentOnScreenChanged)
            .postsVisibilityScrollView()
            .opacity(hidesUntilLanded ? 0 : 1)
            .overlay(Group {
                if hidesUntilLanded {
                    Compat.ProgressView()
                }
            })
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
            attachments: .empty,
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
            relativeDate: "2h",
            topic: "Help",
            groupId: "groupUuid",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canCreateChildren: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
        lockedState: .unlocked,
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
        displayProfile: { _, _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockEnvironmentForPreviews()
}

#Preview("Text and Image") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text"),
            attachments: .images([.init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750))]),
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
            relativeDate: "2h",
            topic: "Help",
            groupId: "groupUuid",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canCreateChildren: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
        lockedState: .unlocked,
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
        displayProfile: { _, _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockEnvironmentForPreviews()
}

#Preview("Text and Poll") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text"),
            attachments: .poll(
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
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h",
            topic: "Help",
            groupId: "groupUuid",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canCreateChildren: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
        lockedState: .unlocked,
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
        displayProfile: { _, _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockEnvironmentForPreviews()
}

#Preview("Text no translation") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: nil),
            attachments: .poll(
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
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h",
            topic: "Help",
            groupId: "groupUuid",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canCreateChildren: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
        lockedState: .unlocked,
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
        displayProfile: { _, _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockEnvironmentForPreviews()
}

#Preview("Bridge Text and Image") {
    ContentView(
        post: .init(
            uuid: "postUuid",
            text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text"),
            attachments: .images([.init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750))]),
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
            relativeDate: "2h",
            topic: "Help",
            groupId: "groupUuid",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            canCreateChildren: true,
            catchPhrase: .init(
                originalText: "Qu'en pensez vous ?",
                originalLanguage: "fr",
                translatedText: "What do you think?"),
            bridgeCTA: nil,
            customAction: nil
        ),
        postNotAvailable: false,
        lockedState: .unlocked,
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
        displayProfile: { _, _ in },
        openCreateComment: { },
        deletePost: { },
        deleteComment: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockEnvironmentForPreviews()
}
