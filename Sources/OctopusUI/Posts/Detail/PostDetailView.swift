//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus

struct PostDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.octopusTheme) private var theme

    @Compat.StateObject private var viewModel: PostDetailViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var showChangesWillBeLostAlert = false

    @State private var displayWillDeleteAlert = false
    @State private var displayPostDeletedAlert = false

    @State private var commentTextFocused: Bool
    @State private var commentHasChanges = false

    @State private var width: CGFloat = 0

    @State private var zoomableImageInfo: ZoomableImageInfo?

    private let canClose: Bool

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, postUuid: String,
         comment: Bool,
         commentToScrollTo: String?,
         scrollToMostRecentComment: Bool = false,
         shouldTrackEventBridgeOpened: Bool = false,
         canClose: Bool = false) {
        _viewModel = Compat.StateObject(wrappedValue: PostDetailViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath, postUuid: postUuid,
            commentToScrollTo: commentToScrollTo,
            scrollToMostRecentComment: scrollToMostRecentComment,
            shouldTrackEventBridgeOpened: shouldTrackEventBridgeOpened))
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
                    displayCommentDetail: { commentId in
                        navigator.push(.commentDetail(commentId: commentId, displayGoToParentButton: false,
                                                      reply: false, replyToScrollTo: nil))
                    },
                    replyToComment: { commentId in
                        navigator.push(.commentDetail(commentId: commentId, displayGoToParentButton: false,
                                                      reply: true, replyToScrollTo: nil))
                    },
                    displayProfile: { profileId in
                        if profileId == viewModel.thisUserProfileId {
                            navigator.push(.currentUserProfile)
                        } else {
                            navigator.push(.publicProfile(profileId: profileId))
                        }
                    },
                    openCreateComment: { commentTextFocused = true },
                    deletePost: viewModel.deletePost,
                    deleteComment: viewModel.deleteComment,
                    togglePostLike: viewModel.togglePostLike,
                    voteOnPoll: viewModel.vote,
                    toggleCommentLike: viewModel.toggleCommentLike,
                    displayContentModeration: {
                        guard viewModel.ensureConnected() else { return }
                        navigator.push(.reportContent(contentId: $0))
                    },
                    displayClientObject: (viewModel.canDisplayClientObject ? { viewModel.displayClientObject(clientObjectId:$0) } : nil)
                )

                CreateCommentView(octopus: viewModel.octopus, postId: viewModel.postUuid,
                                  textFocused: $commentTextFocused,
                                  hasChanges: $commentHasChanges,
                                  ensureConnected: viewModel.ensureConnected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .readWidth($width)

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
        .onDisappear() {
            viewModel.onDisappear()
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Common.CancelModifications", bundle: .module),
                    isPresented: $showChangesWillBeLostAlert) {
                        Button(L10n("Common.No"), role: .cancel, action: {})
                        Button(L10n("Common.Yes"), role: .destructive, action: {
                            if canClose {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                navigator.pop()
                            }
                        })
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
    let displayCommentDetail: (String) -> Void
    let replyToComment: (String) -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let deleteComment: (String) -> Void
    let togglePostLike: () -> Void
    let voteOnPoll: (String) -> Bool
    let toggleCommentLike: (String) -> Void
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    var body: some View {
        Compat.ScrollView(scrollToBottom: $scrollToBottom, scrollToId: $scrollToId, idAnchor: .bottom,
                          refreshAction: refresh) {
            if let post {
                PostDetailContentView(post: post, comments: comments,
                                      hasMoreComments: hasMoreComments,
                                      hideLoadMoreCommentsLoader: hideLoadMoreCommentsLoader,
                                      width: width,
                                      zoomableImageInfo: $zoomableImageInfo,
                                      loadPreviousComments: loadPreviousComments,
                                      displayCommentDetail: displayCommentDetail,
                                      replyToComment: replyToComment,
                                      displayProfile: displayProfile,
                                      openCreateComment: openCreateComment,
                                      deletePost: deletePost,
                                      deleteComment: deleteComment,
                                      togglePostLike: togglePostLike,
                                      voteOnPoll: voteOnPoll,
                                      toggleCommentLike: toggleCommentLike,
                                      displayContentModeration: displayContentModeration,
                                      displayClientObject: displayClientObject)
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
    }
}

private struct PostDetailContentView: View {
    @Environment(\.octopusTheme) private var theme

    let post: PostDetailViewModel.Post
    let comments: [DisplayableFeedResponse]?
    let hasMoreComments: Bool
    let hideLoadMoreCommentsLoader: Bool
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousComments: () -> Void
    let displayCommentDetail: (String) -> Void
    let replyToComment: (String) -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let deleteComment: (String) -> Void
    let togglePostLike: () -> Void
    let voteOnPoll: (String) -> Bool
    let toggleCommentLike: (String) -> Void
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    @State private var displayWillDeleteAlert = false
    @State private var openActions = false

    private let horizontalPadding = CGFloat(16)
    private let minAspectRatio: CGFloat = 4 / 5

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Group { // group views to have the same horizontal padding
                    HStack {
                        OpenProfileButton(author: post.author, displayProfile: displayProfile) {
                            AuthorAvatarView(avatar: post.author.avatar)
                                .frame(width: 40, height: 40)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            AuthorAndDateHeaderView(author: post.author, relativeDate: post.relativeDate,
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
                                            Label(L10n("Post.Delete.Button"), systemImage: "trash")
                                        }
                                    }
                                    if post.canBeModerated {
                                        Button(action: { displayContentModeration(post.uuid) }) {
                                            Label(L10n("Moderation.Content.Button"), systemImage: "flag")
                                        }
                                    }
                                }, label: {
                                    Image(res: .more)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(theme.colors.gray500)
                                })
                                .buttonStyle(.plain)
                            } else {
                                Button(action: { openActions = true }) {
                                    Image(res: .more)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(theme.colors.gray500)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer().frame(height: 10)

                    RichText(post.text)
                        .font(theme.fonts.body2)
                        .lineSpacing(4)
                        .foregroundColor(theme.colors.gray900)
                        .fixedSize(horizontal: false, vertical: true)
                    if let catchPhrase = post.catchPhrase {
                        Spacer().frame(height: 4)
                        Text(catchPhrase)
                            .font(theme.fonts.body2)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.gray900)
                    }

                    Spacer().frame(height: 10)
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
                case let .poll(poll):
                    PollView(poll: poll,
                             aggregatedInfo: post.aggregatedInfo,
                             userInteractions: post.userInteractions,
                             vote: voteOnPoll)
                    .padding(.horizontal, horizontalPadding)
                case .none:
                    EmptyView()
                }

                Spacer().frame(height: post.bridgeCTA == nil || displayClientObject == nil ? 8 : 4)

                HStack {
                    AggregatedInfoView(
                        aggregatedInfo: post.aggregatedInfo, userInteractions: post.userInteractions,
                        displayLabels: post.bridgeCTA == nil || displayClientObject == nil,
                        minChildCount: comments?.count,
                        childrenTapped: { openCreateComment() },
                        likeTapped: togglePostLike)
                    .layoutPriority(1)
                    Spacer()
                    if let bridgeCTA = post.bridgeCTA, let displayClientObject {
                        Button(action: { displayClientObject(bridgeCTA.clientObjectId) }) {
                            Text(bridgeCTA.text)
                                .lineLimit(1)
                        }
                        .buttonStyle(OctopusButtonStyle(.mid(.main)))
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.bottom, post.bridgeCTA == nil || displayClientObject == nil ? 8 : 4)

            theme.colors.gray300.frame(height: 1)

            if let comments {
                CommentsView(comments: comments,
                             hasMoreData: hasMoreComments,
                             hideLoader: hideLoadMoreCommentsLoader,
                             zoomableImageInfo: $zoomableImageInfo,
                             loadPreviousComments: loadPreviousComments,
                             displayCommentDetail: displayCommentDetail,
                             replyToComment: replyToComment,
                             displayProfile: displayProfile,
                             openCreateComment: openCreateComment,
                             deleteComment: deleteComment,
                             toggleLike: toggleCommentLike,
                             displayContentModeration: displayContentModeration)
                .padding(.horizontal, horizontalPadding)
            } else {
                Compat.ProgressView()
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
}

private struct CommentsView: View {
    @Environment(\.octopusTheme) private var theme

    let comments: [DisplayableFeedResponse]
    let hasMoreData: Bool
    let hideLoader: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousComments: () -> Void
    let displayCommentDetail: (String) -> Void
    let replyToComment: (String) -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deleteComment: (String) -> Void
    let toggleLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        Compat.LazyVStack {
            if !comments.isEmpty {
                ForEach(comments, id: \.uuid) { comment in
                    ResponseFeedItemView(
                        response: comment,
                        zoomableImageInfo: $zoomableImageInfo,
                        displayResponseDetail: displayCommentDetail, replyToResponse: replyToComment,
                        displayProfile: displayProfile, deleteResponse: deleteComment,
                        toggleLike: toggleLike, displayContentModeration: displayContentModeration)
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
        .padding(.top, 8)
        .frame(maxHeight: .infinity)
    }
}
