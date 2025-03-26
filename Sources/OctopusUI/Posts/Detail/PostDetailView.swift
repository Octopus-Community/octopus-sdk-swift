//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus

struct PostDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.octopusTheme) private var theme

    @Compat.StateObject private var viewModel: PostDetailViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var topicPickerDetentHeight: CGFloat = 0
    @State private var commentCanBeDismissed = false
    @State private var showChangesWillBeLostAlert = false

    @State private var displayWillDeleteAlert = false
    @State private var displayPostDeletedAlert = false

    @State private var displayProfileId: String?
    @State private var displayProfile = false

    @State private var commentTextFocused = false
    @State private var commentHasChanges = false

    @State private var moderationContext: ReportView.Context?
    @State private var displayContentModeration = false

    // TODO: Delete when router is fully used
    @State private var displaySSOError = false
    @State private var displayableSSOError: DisplayableString?

    @State private var width: CGFloat = 0

    init(octopus: OctopusSDK, postUuid: String, scrollToMostRecentComment: Bool) {
        _viewModel = Compat.StateObject(wrappedValue: PostDetailViewModel(
            octopus: octopus, postUuid: postUuid, scrollToMostRecentComment: scrollToMostRecentComment))
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
                    loadPreviousComments: viewModel.loadPreviousComments,
                    refresh: viewModel.refresh,
                    displayProfile: { profileId in
                        if profileId == viewModel.thisUserProfileId {
                            viewModel.openUserProfile = true
                        } else {
                            displayProfileId = profileId
                            displayProfile = true
                        }
                    },
                    openCreateComment: { commentTextFocused = true },
                    deletePost: viewModel.deletePost,
                    deleteComment: viewModel.deleteComment,
                    togglePostLike: viewModel.togglePostLike,
                    toggleCommentLike: viewModel.toggleCommentLike,
                    displayContentModeration: {
                        guard viewModel.ensureConnected() else { return }
                        moderationContext = .content(contentId: $0)
                        displayContentModeration = true
                    })
                CreateCommentView(octopus: viewModel.octopus, postId: viewModel.postUuid,
                                  textFocused: $commentTextFocused,
                                  hasChanges: $commentHasChanges)
                .overlay(
                    Group {
                        if viewModel.thisUserProfileId == nil {
                            Button(action: { viewModel.createCommentTappedWithoutBeeingLoggedIn() }) {
                                Color.clear
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
            .readWidth()
            .onPreferenceChange(WidthPreferenceKey.self) { [$width] newWidth in
                if let newWidth {
                    $width.wrappedValue = newWidth
                }
            }

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
            $0.navigationBarBackButtonHidden(commentHasChanges)
                .navigationBarItems(leading: commentHasChanges ? leadingBarItem : nil)
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
                    Text("Post.Delete.Done", bundle: .module),
                    isPresented: $displayPostDeletedAlert, actions: {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $displayPostDeletedAlert) {
                    Alert(title: Text("Post.Delete.Done", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        presentationMode.wrappedValue.dismiss()
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
                    Text("Post.Detail.NotAvailable", bundle: .module),
                    isPresented: $viewModel.postNotAvailable, actions: {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Text("Common.Ok", bundle: .module)
                        }

                    })
            } else {
                $0.alert(isPresented: $viewModel.postNotAvailable) {
                    Alert(title: Text("Post.Detail.NotAvailable", bundle: .module),
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
    let post: PostDetailViewModel.Post?
    let comments: [PostDetailViewModel.Comment]?
    let hasMoreComments: Bool
    let hideLoadMoreCommentsLoader: Bool
    let width: CGFloat
    @Binding var scrollToBottom: Bool
    let loadPreviousComments: () -> Void
    let refresh: @Sendable () async -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let deleteComment: (String) -> Void
    let togglePostLike: () -> Void
    let toggleCommentLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        Compat.ScrollView(scrollToBottom: $scrollToBottom, refreshAction: refresh) {
            if let post {
                PostDetailContentView(post: post, comments: comments,
                                      hasMoreComments: hasMoreComments,
                                      hideLoadMoreCommentsLoader: hideLoadMoreCommentsLoader,
                                      width: width,
                                      loadPreviousComments: loadPreviousComments,
                                      displayProfile: displayProfile,
                                      openCreateComment: openCreateComment,
                                      deletePost: deletePost,
                                      deleteComment: deleteComment,
                                      togglePostLike: togglePostLike,
                                      toggleCommentLike: toggleCommentLike,
                                      displayContentModeration: displayContentModeration)
                    .navigationBarTitle(Text(post.topic), displayMode: .inline)
            } else {
                VStack {
                    Spacer().frame(height: 54)
                    Image(.postDetailMissing)
                    Text("Post.Detail.NotAvailable", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray500)
                }
            }
        }
    }
}

private struct PostDetailContentView: View {
    @Environment(\.octopusTheme) private var theme

    let post: PostDetailViewModel.Post
    let comments: [PostDetailViewModel.Comment]?
    let hasMoreComments: Bool
    let hideLoadMoreCommentsLoader: Bool
    let width: CGFloat
    let loadPreviousComments: () -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deletePost: () -> Void
    let deleteComment: (String) -> Void
    let togglePostLike: () -> Void
    let toggleCommentLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    @State private var displayWillDeleteAlert = false
    @State private var openActions = false

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 0) {
                Group { // group views to have the same horizontal padding
                    HStack {
                        OpenProfileButton(author: post.author, displayProfile: displayProfile) {
                            AuthorAvatarView(avatar: post.author.avatar)
                                .frame(width: 33, height: 33)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                OpenProfileButton(author: post.author, displayProfile: displayProfile) {
                                    post.author.name.textView
                                        .font(theme.fonts.caption1)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.colors.gray900)
                                }
                                Circle()
                                    .frame(width: 2, height: 2)
                                    .foregroundColor(theme.colors.gray900)
                                Text(post.relativeDate)
                                    .font(theme.fonts.caption1)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.colors.gray500)
                            }
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

                    Spacer().frame(height: 10)

                    RichText(post.text)
                        .font(theme.fonts.body2)
                        .lineSpacing(4)
                        .foregroundColor(theme.colors.gray900)
                    
                    Spacer().frame(height: 10)
                }.padding(.horizontal, 20)
                if let image = post.image {
                    AsyncCachedImage(
                        url: image.url, cache: .content,
                        placeholder: {
                            theme.colors.gray200
                                .aspectRatio(
                                    image.size.width/image.size.height,
                                    contentMode: .fit)
                                .clipped()
                        },
                        content: { imageToDisplay in
                            imageToDisplay
                                .resizable()
                                .frame(idealWidth: width, idealHeight: image.size.height * width / image.size.width)
                        })
                }

                Spacer().frame(height: 10)

                AggregatedInfoView(aggregatedInfo: post.aggregatedInfo, userInteractions: post.userInteractions,
                                   minChildCount: comments?.count,
                                   childrenTapped: { openCreateComment() },
                                   likeTapped: togglePostLike)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            if let comments {
                CommentsView(comments: comments,
                             hasMoreData: hasMoreComments,
                             hideLoader: hideLoadMoreCommentsLoader,
                             loadPreviousComments: loadPreviousComments,
                             displayProfile: displayProfile,
                             openCreateComment: openCreateComment,
                             deleteComment: deleteComment,
                             toggleLike: toggleCommentLike,
                             displayContentModeration: displayContentModeration)
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

    let comments: [PostDetailViewModel.Comment]
    let hasMoreData: Bool
    let hideLoader: Bool
    let loadPreviousComments: () -> Void
    let displayProfile: (String) -> Void
    let openCreateComment: () -> Void
    let deleteComment: (String) -> Void
    let toggleLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    var body: some View {
        Compat.LazyVStack {
            if !comments.isEmpty {
                ForEach(comments, id: \.uuid) { comment in
                    CommentView(comment: comment, displayProfile: displayProfile, deleteComment: deleteComment,
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
                        Image(.postDetailMissing)
                        Text("Post.Detail.NoComments", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray500)
                    }
                }.buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 20)
            .stroke(theme.colors.gray300, lineWidth: 1)
            .padding(.horizontal, -1)
            .foregroundColor(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .padding(.top, 20)
                    .padding(.bottom, -1)
                    .foregroundColor(Color(.systemBackground))
            )
        )
    }
}
