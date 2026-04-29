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
            comment: comment,
            origin: origin,
            hasFeaturedComment: hasFeaturedComment))
        self.canClose = canClose
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ContentView(
                    post: viewModel.post, postNotAvailable: viewModel.postNotAvailable,
                    comments: viewModel.comments,
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
                        navigator.push(.reportContent(contentId: $0))
                    },
                    displayClientObject: (viewModel.canDisplayClientObject ? { viewModel.displayClientObject(clientObjectId: $0) } : nil)
                )
                .toastContainer(octopus: viewModel.octopus)

                CreateCommentView(octopus: viewModel.octopus, postId: viewModel.postUuid,
                                  translationStore: translationStore,
                                  textFocused: $viewModel.commentTextFocused,
                                  hasChanges: $commentHasChanges,
                                  ensureConnected: viewModel.ensureConnected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.postDeletion == .inProgress || viewModel.isDeletingComment {
                LoadingOverlay()
            }
        }
        .readWidth($width)
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
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
            "Common.CancelModifications",
            isPresented: $showChangesWillBeLostAlert,
            cancelLabel: "Common.No",
            destructiveLabel: "Common.Yes",
            action: {
                if canClose {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    navigator.pop()
                }
            })
        .destructiveConfirmationAlert(
            "Block.Profile.Alert.Title",
            isPresented: $displayWillBlockAlert,
            destructiveLabel: "Common.Continue",
            action: {
                if let profileId = viewModel.post?.author.profileId {
                    viewModel.blockAuthor(profileId: profileId)
                }
            },
            message: "Block.Profile.Alert.Message")
        .destructiveConfirmationAlert(
            "Post.Delete.Confirmation.Title",
            isPresented: $displayWillDeleteAlert,
            destructiveLabel: "Common.Delete",
            action: { viewModel.deletePost() })
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Done", bundle: .module),
                    isPresented: $displayPostDeletedAlert, actions: {
                        Button(action: {
                            if canClose {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                navigator.pop()
                            }
                        }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $displayPostDeletedAlert) {
                    Alert(title: Text("Post.Delete.Done", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        if canClose {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            navigator.pop()
                        }
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
                    isPresented: $viewModel.postDisappeared, actions: {
                        Button(action: {
                            if canClose {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                navigator.pop()
                            }
                        }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $viewModel.postDisappeared) {
                    Alert(title: Text("Content.Detail.NotAvailable", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        if canClose {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            navigator.pop()
                        }
                    }))
                }
            }
        }
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if canClose {
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
           post.canBeDeleted || post.canBeModerated || post.canBeBlockedByUser {
            Menu(content: {
                if post.canBeDeleted {
                    Button(action: { displayWillDeleteAlert = true }) {
                        Label(title: { Text("Post.Delete.Button", bundle: .module) },
                              icon: { Image(uiImage: theme.assets.icons.content.delete) })
                    }
                }
                if post.canBeModerated {
                    DestructiveMenuButton(action: {
                        guard viewModel.ensureConnected(action: .moderation) else { return }
                        navigator.push(.reportContent(contentId: post.uuid))
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
                if #available(iOS 26.0, *) {
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
            Text("Post.Title_author:\(authorName.localizedString(locale: languageManager.overridenLocale))",
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
    let blockAuthor: (String) -> Void
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
            } else if #unavailable(iOS 16.0) {
                Color.white.opacity(0.0001)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
#endif
            Compat.ScrollView(scrollToBottom: $scrollToBottom, scrollToId: $scrollToId, idAnchor: .bottom,
                              refreshAction: refresh) {
                LazyIfPossibleVStack(spacing: 0, preventLaziness: scrollToBottom || scrollToId != nil) {
                    if let post {
                        PostDetailContentView(post: post,
                                              width: width,
                                              zoomableImageInfo: $zoomableImageInfo,
                                              displayProfile: displayProfile,
                                              openCreateComment: openCreateComment,
                                              deletePost: deletePost,
                                              blockAuthor: blockAuthor,
                                              reactionTapped: reactionTapped,
                                              voteOnPoll: voteOnPoll,
                                              displayContentModeration: displayContentModeration,
                                              displayClientObject: displayClientObject)

                        theme.colors.gray300.frame(height: 2)
                        Spacer().frame(height: 10)

                        if let comments {
                            PostDetailCommentsView(comments: comments,
                                         hasMoreData: hasMoreComments,
                                         hideLoader: hideLoadMoreCommentsLoader,
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
                        } else {
                            Compat.ProgressView()
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
                    } else {
                        VStack {
                            Spacer()
                            Compat.ProgressView()
                            Spacer()
                        }
                    }
                }
            }.postsVisibilityScrollView()
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
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
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
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
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
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
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
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            catchPhrase: nil,
            bridgeCTA: nil,
            customAction: nil),
        postNotAvailable: false,
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
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            topic: "Help",
            aggregatedInfo: .init(reactions: [
                .init(reactionKind: .heart, count: 10),
                .init(reactionKind: .clap, count: 5),
            ], childCount: 5, viewCount: 4, pollResult: nil),
            userInteractions: .empty,
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            catchPhrase: .init(
                originalText: "Qu'en pensez vous ?",
                originalLanguage: "fr",
                translatedText: "What do you think?"),
            bridgeCTA: nil,
            customAction: nil
        ),
        postNotAvailable: false,
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
        blockAuthor: { _ in },
        reactionTapped: { _ in },
        voteOnPoll: { _ in false },
        commentReactionTapped: { _, _ in },
        displayContentModeration: { _ in },
        displayClientObject: nil
    )
    .mockEnvironmentForPreviews()
}
