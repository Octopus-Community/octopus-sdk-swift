//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus

struct CommentDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.octopusTheme) private var theme

    @Compat.StateObject private var viewModel: CommentDetailViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var showChangesWillBeLostAlert = false

    @State private var displayWillDeleteAlert = false
    @State private var displayPostDeletedAlert = false

    @State private var displayProfileId: String?
    @State private var displayProfile = false

    @State private var replyTextFocused: Bool
    @State private var replyHasChanges = false

    @State private var moderationContext: ReportView.Context?
    @State private var displayContentModeration = false

    // TODO: Delete when router is fully used
    @State private var displaySSOError = false
    @State private var displayableSSOError: DisplayableString?

    @State private var width: CGFloat = 0

    init(octopus: OctopusSDK, commentUuid: String, reply: Bool) {
        _viewModel = Compat.StateObject(wrappedValue: CommentDetailViewModel(
            octopus: octopus, commentUuid: commentUuid, reply: reply))
        _replyTextFocused = .init(initialValue: reply)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ContentView(
                    comment: viewModel.comment, replies: viewModel.replies,
                    hasMoreReplies: viewModel.hasMoreData,
                    hideLoadMoreRepliesLoader: viewModel.hideLoadMoreRepliesLoader,
                    width: width,
                    scrollToBottom: $viewModel.scrollToBottom,
                    loadPreviousReplies: viewModel.loadPreviousReplies,
                    refresh: viewModel.refresh,
                    displayProfile: { profileId in
                        if profileId == viewModel.thisUserProfileId {
                            viewModel.openUserProfile = true
                        } else {
                            displayProfileId = profileId
                            displayProfile = true
                        }
                    },
                    openCreateReply: { replyTextFocused = true },
                    deleteComment: viewModel.deleteComment,
                    deleteReply: viewModel.deleteReply,
                    toggleCommentLike: viewModel.toggleCommentLike,
                    toggleReplyLike: viewModel.toggleReplyLike,
                    displayContentModeration: {
                        guard viewModel.ensureConnected() else { return }
                        moderationContext = .content(contentId: $0)
                        displayContentModeration = true
                    })

                CreateReplyView(octopus: viewModel.octopus, commentId: viewModel.commentUuid,
                                textFocused: $replyTextFocused,
                                hasChanges: $replyHasChanges)
                .overlay(
                    Group {
                        if viewModel.thisUserProfileId == nil {
                            Button(action: { viewModel.createReplyTappedWithoutBeeingLoggedIn() }) {
                                Color.white.opacity(0.0001)
                            }
                            .buttonStyle(.plain)
                        } else {
                            EmptyView()
                        }
                    }
                )
                NavigationLink(destination:
                                Group {
                    if let displayProfileId {
                        ProfileSummaryView(octopus: viewModel.octopus, profileId: displayProfileId)
                    } else {
                        EmptyView()
                    }
                }, isActive: $displayProfile) {
                    EmptyView()
                }.hidden()

                NavigationLink(
                    destination: Group {
                        if let moderationContext {
                            ReportView(octopus: viewModel.octopus, context: moderationContext)
                        } else { EmptyView() }
                    },
                    isActive: $displayContentModeration) {
                        EmptyView()
                    }.hidden()
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
        .navigationBarTitle(Text("Comment.Detail.Title", bundle: .module), displayMode: .inline)
        .alert(
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
        .background(
            NavigationLink(destination: CurrentUserProfileSummaryView(octopus: viewModel.octopus, dismiss: !$viewModel.openUserProfile),
                           isActive: $viewModel.openUserProfile) {
                               EmptyView()
                           }.hidden()
        )
        .fullScreenCover(isPresented: $viewModel.openLogin) {
            MagicLinkView(octopus: viewModel.octopus, isLoggedIn: .constant(false))
                .environment(\.dismissModal, $viewModel.openLogin)
        }
        .fullScreenCover(isPresented: $viewModel.openCreateProfile) {
            NavigationView {
                CreateProfileView(octopus: viewModel.octopus, isLoggedIn: .constant(false))
                    .environment(\.dismissModal, $viewModel.openCreateProfile)
            }
            .navigationBarHidden(true)
            .accentColor(theme.colors.primary)
        }
        .modify {
            $0.navigationBarBackButtonHidden(replyHasChanges)
                .navigationBarItems(leading: replyHasChanges ? leadingBarItem : nil)
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Common.CancelModifications", bundle: .module),
                    isPresented: $showChangesWillBeLostAlert) {
                        Button(L10n("Common.No"), role: .cancel, action: {})
                        Button(L10n("Common.Yes"), role: .destructive, action: { presentationMode.wrappedValue.dismiss() })
                    }
            } else {
                $0.alert(isPresented: $showChangesWillBeLostAlert) {
                    Alert(title: Text("Common.CancelModifications", bundle: .module),
                          primaryButton: .default(Text("Common.No", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Yes", bundle: .module),
                            action: { presentationMode.wrappedValue.dismiss() }
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
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $displayPostDeletedAlert) {
                    Alert(title: Text("Comment.Delete.Done", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        presentationMode.wrappedValue.dismiss()
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
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Text("Common.Ok", bundle: .module)
                        }

                    })
            } else {
                $0.alert(isPresented: $viewModel.commentNotAvailable) {
                    Alert(title: Text("Content.Detail.NotAvailable", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        presentationMode.wrappedValue.dismiss()
                    }))
                }
            }
        }
        .alert(
            "Common.Error",
            isPresented: $displaySSOError,
            presenting: displayableSSOError,
            actions: { _ in
                Button(action: viewModel.linkClientUserToOctopusUser) {
                    Text("Common.Retry", bundle: .module)
                }
                Button(action: {}) {
                    Text("Common.Cancel", bundle: .module)
                }
            },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$ssoError) { error in
            guard let error else { return }
            displayableSSOError = error
            displaySSOError = true
        }
    }

    private var leadingBarItem: some View {
        Button(action: {
            showChangesWillBeLostAlert = true
        }) {
            Image(systemName: "chevron.left")
                .font(theme.fonts.navBarItem.weight(.semibold))
        }
        .padding(.leading, -8)
        .padding(.trailing, 16)
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    let comment: CommentDetailViewModel.CommentDetail?
    let replies: [DisplayableFeedResponse]?
    let hasMoreReplies: Bool
    let hideLoadMoreRepliesLoader: Bool
    let width: CGFloat
    @Binding var scrollToBottom: Bool
    let loadPreviousReplies: () -> Void
    let refresh: @Sendable () async -> Void
    let displayProfile: (String) -> Void
    let openCreateReply: () -> Void
    let deleteComment: () -> Void
    let deleteReply: (String) -> Void
    let toggleCommentLike: () -> Void
    let toggleReplyLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        Compat.ScrollView(scrollToBottom: $scrollToBottom, refreshAction: refresh) {
            if let comment {
                CommentDetailContentView(comment: comment, replies: replies,
                                         hasMoreReplies: hasMoreReplies,
                                         hideLoadMoreRepliesLoader: hideLoadMoreRepliesLoader,
                                         width: width,
                                         loadPreviousReplies: loadPreviousReplies,
                                         displayProfile: displayProfile,
                                         openCreateReply: openCreateReply,
                                         deleteComment: deleteComment,
                                         deleteReply: deleteReply,
                                         toggleCommentLike: toggleCommentLike,
                                         toggleReplyLike: toggleReplyLike,
                                         displayContentModeration: displayContentModeration)
            } else {
                VStack {
                    Spacer().frame(height: 54)
                    Image(.postDetailMissing)
                    Text("Content.Detail.NotAvailable", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray500)
                }
            }
        }
    }
}

private struct CommentDetailContentView: View {
    @Environment(\.octopusTheme) private var theme

    let comment: CommentDetailViewModel.CommentDetail
    let replies: [DisplayableFeedResponse]?
    let hasMoreReplies: Bool
    let hideLoadMoreRepliesLoader: Bool
    let width: CGFloat
    let loadPreviousReplies: () -> Void
    let displayProfile: (String) -> Void
    let openCreateReply: () -> Void
    let deleteComment: () -> Void
    let deleteReply: (String) -> Void
    let toggleCommentLike: () -> Void
    let toggleReplyLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    @State private var displayWillDeleteAlert = false
    @State private var openActions = false

    var body: some View {
        VStack {
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
                                placeholder: {
                                    theme.colors.gray200
                                        .aspectRatio(
                                            image.size.width/image.size.height,
                                            contentMode: .fit)
                                        .clipped()
                                },
                                content: { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(12)
                                })
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
                    .padding(.top, 6)
                }
            }
            .id("commentDetail-\(comment.uuid)")

            if let replies {
                RepliesView(replies: replies,
                            hasMoreData: hasMoreReplies,
                            hideLoader: hideLoadMoreRepliesLoader,
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
    let loadPreviousReplies: () -> Void
    let displayProfile: (String) -> Void
    let deleteReply: (String) -> Void
    let toggleLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 40)
            Compat.LazyVStack {
                ForEach(replies, id: \.uuid) { reply in
                    ResponseFeedItemView(
                        response: reply,
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
        .padding(.top, 20)
        .frame(maxHeight: .infinity)
    }
}
