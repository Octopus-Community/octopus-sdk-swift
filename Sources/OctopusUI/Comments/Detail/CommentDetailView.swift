//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus
import OctopusCore

struct CommentDetailView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.trackingApi) var trackingApi
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    @Compat.StateObject private var viewModel: CommentDetailViewModel

    @State private var showChangesWillBeLostAlert = false

    @State private var displayWillDeleteAlert = false
    @State private var displayPostDeletedAlert = false

    @State private var replyTextFocused: Bool
    @State private var replyHasChanges = false

    @State private var zoomableImageInfo: ZoomableImageInfo?

    let displayGoToParentButton: Bool

    init(
        octopus: OctopusSDK,
        translationStore: ContentTranslationPreferenceStore,
        commentUuid: String, displayGoToParentButton: Bool,
        reply: Bool = false,
        replyToScrollTo: String? = nil) {
            _viewModel = Compat.StateObject(wrappedValue: CommentDetailViewModel(
                octopus: octopus, translationStore: translationStore, commentUuid: commentUuid,
                reply: reply, replyToScrollTo: replyToScrollTo))
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
                        trackingApi.emit(event: .replyButtonClicked(.init(commentId: viewModel.commentUuid)))
                        replyTextFocused = true
                    },
                    deleteComment: viewModel.deleteComment,
                    deleteReply: viewModel.deleteReply,
                    blockAuthor: viewModel.blockAuthor(profileId:),
                    reactionTapped: viewModel.setReaction(_:),
                    replyReactionTapped: viewModel.setReplyReaction(_:replyId:),
                    displayContentModeration: {
                        guard viewModel.ensureConnected(action: .moderation) else { return }
                        navigator.push(.reportContent(contentId: $0))
                    },
                    displayParentPost: {
                        navigator.push(.postDetail(postId: $0, comment: false, commentToScrollTo: $1,
                                                   scrollToMostRecentComment: false, origin: .sdk,
                                                   hasFeaturedComment: false))
                    })
                .toastContainer(octopus: viewModel.octopus)

                CreateReplyView(octopus: viewModel.octopus, commentId: viewModel.commentUuid,
                                translationStore: translationStore,
                                textFocused: $replyTextFocused,
                                hasChanges: $replyHasChanges,
                                ensureConnected: viewModel.ensureConnected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.commentDeletion == .inProgress || viewModel.isDeletingReply {
                LoadingOverlay()
            }
        }
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarTitle: Text("Comment.Detail.Title", bundle: .module),
                                defaultNavigationBarBackButtonHidden: replyHasChanges)
        .errorAlert(viewModel.$error)
        .onReceive(viewModel.$commentDeletion) { commentDeletion in
            if commentDeletion == .done {
                displayPostDeletedAlert = true
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .emitScreenDisplayed(.commentDetail(.init(commentId: viewModel.commentUuid)), trackingApi: trackingApi)
        .onDisappear {
            viewModel.onDisappear()
        }
        .destructiveConfirmationAlert(
            "Common.CancelModifications",
            isPresented: $showChangesWillBeLostAlert,
            cancelLabel: "Common.No",
            destructiveLabel: "Common.Yes",
            action: { navigator.pop() })
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
            BackButton(action: { showChangesWillBeLostAlert = true })
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
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let replyReactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (String) -> Void
    let displayParentPost: (String, String) -> Void

    var body: some View {
        Compat.ScrollView(
            scrollToBottom: $scrollToBottom, scrollToId: $scrollToId, idAnchor: .bottom,
            refreshAction: refresh) {
                LazyIfPossibleVStack(spacing: 0, preventLaziness: scrollToBottom || scrollToId != nil) {
                    if let comment {
                        CommentDetailContentView(comment: comment,
                                                 displayGoToParentButton: displayGoToParentButton,
                                                 zoomableImageInfo: $zoomableImageInfo,
                                                 displayProfile: displayProfile,
                                                 openCreateReply: openCreateReply,
                                                 deleteComment: deleteComment,
                                                 blockAuthor: blockAuthor,
                                                 reactionTapped: reactionTapped,
                                                 displayContentModeration: displayContentModeration,
                                                 displayParentPost: displayParentPost)

                        if let replies {
                            CommentDetailRepliesView(replies: replies,
                                        hasMoreData: hasMoreReplies,
                                        hideLoader: hideLoadMoreRepliesLoader,
                                        zoomableImageInfo: $zoomableImageInfo,
                                        loadPreviousReplies: loadPreviousReplies,
                                        displayProfile: displayProfile,
                                        deleteReply: deleteReply,
                                        blockAuthor: blockAuthor,
                                        reactionTapped: replyReactionTapped,
                                        displayContentModeration: displayContentModeration)
                        } else {
                            Compat.ProgressView()
                        }
                    } else {
                        VStack {
                            Spacer().frame(height: 54)
                            IconImage(theme.assets.icons.content.comment.notAvailable)
                                .accessibilityHidden(true)
                            Text("Content.Detail.NotAvailable", bundle: .module)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                        }
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray500)
                    }
                }
            }
            .clipped()
    }
}
