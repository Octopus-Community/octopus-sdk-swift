//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus

struct CommentDetailView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.octopusTheme) private var theme

    @Compat.StateObject private var viewModel: CommentDetailViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var showChangesWillBeLostAlert = false

    @State private var displayWillDeleteAlert = false
    @State private var displayPostDeletedAlert = false

    @State private var replyTextFocused: Bool
    @State private var replyHasChanges = false

    @State private var width: CGFloat = 0

    @State private var zoomableImageInfo: ZoomableImageInfo?

    let displayGoToParentButton: Bool

    init(
        octopus: OctopusSDK,
        commentUuid: String, displayGoToParentButton: Bool,
        reply: Bool = false,
        replyToScrollTo: String? = nil) {
            _viewModel = Compat.StateObject(wrappedValue: CommentDetailViewModel(
                octopus: octopus, commentUuid: commentUuid, reply: reply, replyToScrollTo: replyToScrollTo))
            _replyTextFocused = .init(initialValue: reply)
            self.displayGoToParentButton = displayGoToParentButton
        }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ContentView(
                    comment: viewModel.comment, replies: viewModel.replies,
                    hasMoreReplies: viewModel.hasMoreData,
                    hideLoadMoreRepliesLoader: viewModel.hideLoadMoreRepliesLoader,
                    width: width,
                    displayGoToParentButton: displayGoToParentButton,
                    scrollToBottom: $viewModel.scrollToBottom,
                    scrollToId: $viewModel.scrollToId,
                    zoomableImageInfo: $zoomableImageInfo,
                    loadPreviousReplies: viewModel.loadPreviousReplies,
                    refresh: viewModel.refresh,
                    displayProfile: { profileId in
                        if profileId == viewModel.thisUserProfileId {
                            navigator.push(.currentUserProfile)
                        } else {
                            navigator.push(.publicProfile(profileId: profileId))
                        }
                    },
                    openCreateReply: {
                        replyTextFocused = true
                    },
                    deleteComment: viewModel.deleteComment,
                    deleteReply: viewModel.deleteReply,
                    toggleCommentLike: viewModel.toggleCommentLike,
                    toggleReplyLike: viewModel.toggleReplyLike,
                    displayContentModeration: {
                        guard viewModel.ensureConnected() else { return }
                        navigator.push(.reportContent(contentId: $0))
                    },
                    displayParentPost: {
                        navigator.push(.postDetail(postId: $0, comment: false, commentToScrollTo: $1,
                                                   scrollToMostRecentComment: false))
                    })

                CreateReplyView(octopus: viewModel.octopus, commentId: viewModel.commentUuid,
                                textFocused: $replyTextFocused,
                                hasChanges: $replyHasChanges,
                                ensureConnected: viewModel.ensureConnected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .readWidth($width)

            if viewModel.commentDeletion == .inProgress || viewModel.isDeletingReply {
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
                                defaultNavigationBarTitle: Text("Comment.Detail.Title", bundle: .module),
                                defaultNavigationBarBackButtonHidden: replyHasChanges)
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
        .onReceive(viewModel.$commentDeletion) { commentDeletion in
            if commentDeletion == .done {
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
                        Button(L10n("Common.Yes"), role: .destructive, action: { navigator.pop() })
                    }
            } else {
                $0.alert(isPresented: $showChangesWillBeLostAlert) {
                    Alert(title: Text("Common.CancelModifications", bundle: .module),
                          primaryButton: .default(Text("Common.No", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Yes", bundle: .module),
                            action: { navigator.pop() }
                          )
                    )
                }
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Comment.Delete.Done", bundle: .module),
                    isPresented: $displayPostDeletedAlert, actions: {
                        Button(action: { navigator.pop() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $displayPostDeletedAlert) {
                    Alert(title: Text("Comment.Delete.Done", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        navigator.pop()
                    }))
                }
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Reply.Delete.Done", bundle: .module),
                    isPresented: $viewModel.replyDeleted, actions: { })
            } else {
                $0.alert(isPresented: $viewModel.replyDeleted) {
                    Alert(title: Text("Reply.Delete.Done", bundle: .module))
                }
            }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Content.Detail.NotAvailable", bundle: .module),
                    isPresented: $viewModel.commentNotAvailable, actions: {
                        Button(action: { navigator.pop() }) {
                            Text("Common.Ok", bundle: .module)
                        }

                    })
            } else {
                $0.alert(isPresented: $viewModel.commentNotAvailable) {
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
        if replyHasChanges {
            Button(action: {
                showChangesWillBeLostAlert = true
            }) {
                Image(systemName: "chevron.left")
                    .font(theme.fonts.navBarItem.weight(.semibold))
                    .contentShape(Rectangle())
                    .padding(.trailing, 40)
            }
            .padding(.leading, -8)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        EmptyView()
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    let comment: CommentDetailViewModel.CommentDetail?
    let replies: [DisplayableFeedResponse]?
    let hasMoreReplies: Bool
    let hideLoadMoreRepliesLoader: Bool
    let width: CGFloat
    let displayGoToParentButton: Bool
    @Binding var scrollToBottom: Bool
    @Binding var scrollToId: String?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousReplies: () -> Void
    let refresh: @Sendable () async -> Void
    let displayProfile: (String) -> Void
    let openCreateReply: () -> Void
    let deleteComment: () -> Void
    let deleteReply: (String) -> Void
    let toggleCommentLike: () -> Void
    let toggleReplyLike: (String) -> Void
    let displayContentModeration: (String) -> Void
    let displayParentPost: (String, String) -> Void

    var body: some View {
        Compat.ScrollView(
            scrollToBottom: $scrollToBottom, scrollToId: $scrollToId, idAnchor: .bottom,
            refreshAction: refresh) {
                if let comment {
                    CommentDetailContentView(comment: comment, replies: replies,
                                             hasMoreReplies: hasMoreReplies,
                                             hideLoadMoreRepliesLoader: hideLoadMoreRepliesLoader,
                                             width: width,
                                             displayGoToParentButton: displayGoToParentButton,
                                             zoomableImageInfo: $zoomableImageInfo,
                                             loadPreviousReplies: loadPreviousReplies,
                                             displayProfile: displayProfile,
                                             openCreateReply: openCreateReply,
                                             deleteComment: deleteComment,
                                             deleteReply: deleteReply,
                                             toggleCommentLike: toggleCommentLike,
                                             toggleReplyLike: toggleReplyLike,
                                             displayContentModeration: displayContentModeration,
                                             displayParentPost: displayParentPost)
                } else {
                    VStack {
                        Spacer().frame(height: 54)
                        Image(.contentNotAvailable)
                        Text("Content.Detail.NotAvailable", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(theme.colors.gray500)
                }
            }
            .clipped()
    }
}

private struct CommentDetailContentView: View {
    @Environment(\.octopusTheme) private var theme

    let comment: CommentDetailViewModel.CommentDetail
    let replies: [DisplayableFeedResponse]?
    let hasMoreReplies: Bool
    let hideLoadMoreRepliesLoader: Bool
    let width: CGFloat
    let displayGoToParentButton: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousReplies: () -> Void
    let displayProfile: (String) -> Void
    let openCreateReply: () -> Void
    let deleteComment: () -> Void
    let deleteReply: (String) -> Void
    let toggleCommentLike: () -> Void
    let toggleReplyLike: (String) -> Void
    let displayContentModeration: (String) -> Void
    let displayParentPost: (String, String) -> Void

    @State private var displayWillDeleteAlert = false
    @State private var openActions = false

    private let minAspectRatio: CGFloat = 4 / 5

    var body: some View {
        VStack(spacing: 0) {
            if displayGoToParentButton {
                Button(action: { displayParentPost(comment.parentId, comment.uuid) }) {
                    Text("Comment.SeeParent", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray900)
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .background(
                            Capsule()
                                .stroke(theme.colors.gray300, lineWidth: 1)
                        )
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .buttonStyle(.plain)
            }
            HStack(alignment: .top) {
                OpenProfileButton(author: comment.author, displayProfile: displayProfile) {
                    AuthorAvatarView(avatar: comment.author.avatar)
                        .frame(width: 32, height: 32)
                }
                VStack(spacing: 0) {
                    VStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 4) {
                                AuthorAndDateHeaderView(author: comment.author, relativeDate: comment.relativeDate,
                                                        displayProfile: displayProfile)
                                Spacer()
                                if comment.canBeDeleted || comment.canBeModerated {
                                    if #available(iOS 14.0, *) {
                                        Menu(content: {
                                            if comment.canBeDeleted {
                                                Button(action: { displayWillDeleteAlert = true }) {
                                                    Label(L10n("Comment.Delete.Button"), systemImage: "trash")
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            if comment.canBeModerated {
                                                Button(action: { displayContentModeration(comment.uuid) }) {
                                                    Label(L10n("Moderation.Content.Button"), systemImage: "flag")
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }, label: {
                                            Image(.more)
                                                .resizable()
                                                .frame(width: 24, height: 24)
                                                .foregroundColor(theme.colors.gray500)
                                        })
                                        .buttonStyle(.plain)
                                    } else {
                                        Button(action: { openActions = true }) {
                                            Image(.more)
                                                .resizable()
                                                .frame(width: 24, height: 24)
                                                .foregroundColor(theme.colors.gray500)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            if let text = comment.text?.nilIfEmpty {
                                RichText(text)
                                    .font(theme.fonts.body2)
                                    .lineSpacing(4)
                                    .foregroundColor(theme.colors.gray900)
                            }
                        }.padding(8)
                        if let image = comment.image {
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
                            .fixedSize(horizontal: false, vertical: true)
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerSize: CGSize(width: 12, height: 12))
                            .foregroundColor(theme.colors.primaryLowContrast)
                    )

                    let userInteractions = comment.userInteractions
                    let aggregatedInfo = comment.aggregatedInfo
                    HStack(spacing: 24) {
                        Button(action: toggleCommentLike) {
                            AggregateView(image: userInteractions.hasLiked ? .AggregatedInfo.likeActivated : .AggregatedInfo.like,
                                          imageForegroundColor: userInteractions.hasLiked ?
                                          theme.colors.like : theme.colors.gray700,
                                          count: aggregatedInfo.likeCount,
                                          nullDisplayValue: "Content.AggregatedInfo.Like")
                        }
                        .buttonStyle(.plain)

                        Button(action: openCreateReply) {
                            AggregateView(image: .AggregatedInfo.comment, count: 0,
                                          nullDisplayValue: "Content.AggregatedInfo.Answer")
                        }
                        .buttonStyle(.plain)
                    }
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
            }
            .id("commentDetail-\(comment.uuid)")

            if let replies {
                RepliesView(replies: replies,
                            hasMoreData: hasMoreReplies,
                            hideLoader: hideLoadMoreRepliesLoader,
                            zoomableImageInfo: $zoomableImageInfo,
                            loadPreviousReplies: loadPreviousReplies,
                            displayProfile: displayProfile,
                            deleteReply: deleteReply,
                            toggleLike: toggleReplyLike,
                            displayContentModeration: displayContentModeration)
            } else {
                Compat.ProgressView()
            }

        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: actionSheetContent)
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Comment.Delete.Confirmation.Title", bundle: .module),
                    isPresented: $displayWillDeleteAlert) {
                        Button(role: .cancel, action: {}, label: { Text("Common.Cancel", bundle: .module) })
                        Button(role: .destructive, action: { deleteComment() },
                               label: { Text("Common.Delete", bundle: .module) })
                    }
            } else {
                $0.alert(isPresented: $displayWillDeleteAlert) {
                    Alert(title: Text("Comment.Delete.Confirmation.Title",
                                      bundle: .module),
                          primaryButton: .default(Text("Common.Cancel", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Delete", bundle: .module),
                            action: { deleteComment() }
                          )
                    )
                }
            }
        }
    }

    var actionSheetContent: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if comment.canBeDeleted {
            buttons.append(ActionSheet.Button.destructive(Text("Post.Delete.Button", bundle: .module)) {
                displayWillDeleteAlert = true
            })
        }
        if comment.canBeModerated {
            buttons.append(ActionSheet.Button.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(comment.uuid)
            })
        }

        buttons.append(.cancel())
        return buttons
    }
}

private struct RepliesView: View {
    @Environment(\.octopusTheme) private var theme

    let replies: [DisplayableFeedResponse]
    let hasMoreData: Bool
    let hideLoader: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousReplies: () -> Void
    let displayProfile: (String) -> Void
    let deleteReply: (String) -> Void
    let toggleLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer().frame(width: 40)
            Compat.LazyVStack {
                ForEach(replies, id: \.uuid) { reply in
                    ResponseFeedItemView(
                        response: reply,
                        zoomableImageInfo: $zoomableImageInfo,
                        displayResponseDetail: { _ in }, replyToResponse: { _ in },
                        displayProfile: displayProfile, deleteResponse: deleteReply,
                        toggleLike: toggleLike, displayContentModeration: displayContentModeration)
                    .onAppear {
                        reply.displayEvents.onAppear()
                    }
                    .onDisappear() {
                        reply.displayEvents.onDisappear()
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
                            loadPreviousReplies()
                        }
                }
            }
        }
        .padding(.top, 16)
        .frame(maxHeight: .infinity)
    }
}
