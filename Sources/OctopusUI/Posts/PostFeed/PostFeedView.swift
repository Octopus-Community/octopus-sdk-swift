//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore
import os

struct PostFeedView<EmptyPostView: View>: View {
    @Environment(\.presentationMode) private var presentationMode
    @Compat.StateObject private var viewModel: PostFeedViewModel

    @Binding var zoomableImageInfo: ZoomableImageInfo?

    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool, _ scrollToComment: String?, _ hasFeaturedComment: Bool) -> Void
    let displayCommentDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (String) -> Void
    let displayContentModeration: (String) -> Void

    @ViewBuilder var emptyPostView: EmptyPostView

    @State private var displayReactionCount = false

    init(viewModel: PostFeedViewModel,
         zoomableImageInfo: Binding<ZoomableImageInfo?>,
         displayPostDetail: @escaping (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool, _ scrollToComment: String?, _ hasFeaturedComment: Bool) -> Void,
         displayCommentDetail: @escaping (_ id: String, _ reply: Bool) -> Void,
         displayProfile: @escaping (String) -> Void,
         displayContentModeration: @escaping (String) -> Void,
         @ViewBuilder _ emptyPostView: () -> EmptyPostView) {
        _viewModel = Compat.StateObject(wrappedValue: viewModel)
        _zoomableImageInfo = zoomableImageInfo
        self.displayPostDetail = displayPostDetail
        self.displayCommentDetail = displayCommentDetail
        self.displayProfile = displayProfile
        self.displayContentModeration = displayContentModeration
        self.emptyPostView = emptyPostView()
    }

    var body: some View {
        ZStack {
            ContentView(
                posts: viewModel.posts,
                displayGroup: viewModel.displayGroup,
                hasMoreData: viewModel.hasMoreData,
                zoomableImageInfo: $zoomableImageInfo,
                loadPreviousItems: viewModel.loadPreviousItems,
                displayPostDetail: displayPostDetail,
                displayCommentDetail: displayCommentDetail,
                displayProfile: displayProfile,
                deletePost: viewModel.deletePost(postId:),
                deleteComment: viewModel.deleteComment(commentId:),
                blockAuthor: viewModel.blockAuthor(profileId:),
                reactionTapped: viewModel.setReaction(_:postId:),
                commentReactionTapped: viewModel.setCommentReaction(_:commentId:),
                voteOnPoll: viewModel.vote(pollAnswerId:postId:),
                displayContentModeration: {
                    if viewModel.ensureConnected(.moderation) {
                        displayContentModeration($0)
                    }
                },
                displayClientObject: (viewModel.canDisplayClientObject ? { viewModel.displayClientObject(clientObjectId: $0) } : nil),
                emptyPostView: { emptyPostView }
            )
            if viewModel.isDeletingContent {
                LoadingOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .errorAlert(viewModel.$error)
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Done", bundle: .module),
                    isPresented: $viewModel.contentDeleted, actions: { })
            } else {
                $0.alert(isPresented: $viewModel.contentDeleted) {
                    Alert(title: Text("Post.Delete.Done", bundle: .module))
                }
            }
        }
    }
}

private struct ContentView<EmptyPostView: View>: View {
    let posts: [DisplayablePost]?
    let displayGroup: Bool
    let hasMoreData: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousItems: () -> Void
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool, _ scrollToComment: String?, _ hasFeaturedComment: Bool) -> Void
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
    @ViewBuilder var emptyPostView: EmptyPostView

    var body: some View {
        Group {
            if let posts {
                PostsView(posts: posts,
                          displayGroup: displayGroup,
                          hasMoreData: hasMoreData,
                          zoomableImageInfo: $zoomableImageInfo,
                          loadPreviousItems: loadPreviousItems,
                          displayPostDetail: displayPostDetail,
                          displayCommentDetail: displayCommentDetail,
                          displayProfile: displayProfile,
                          deletePost: deletePost,
                          deleteComment: deleteComment,
                          blockAuthor: blockAuthor,
                          reactionTapped: reactionTapped,
                          commentReactionTapped: commentReactionTapped,
                          voteOnPoll: voteOnPoll,
                          displayContentModeration: displayContentModeration,
                          displayClientObject: displayClientObject,
                          emptyPostView: { emptyPostView })
            } else {
                Compat.ProgressView()
                    .frame(width: 100)
                    .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PostsView<EmptyPostView: View>: View {
    let posts: [DisplayablePost]
    let displayGroup: Bool
    let hasMoreData: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousItems: () -> Void
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool, _ scrollToComment: String?, _ hasFeaturedComment: Bool) -> Void
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
    @ViewBuilder var emptyPostView: EmptyPostView

    @State private var width: CGFloat = 0

    var body: some View {
        if !posts.isEmpty {
            Compat.LazyVStack(spacing: 0) {
                ForEach(posts, id: \.uuid) { post in
                    PostSummaryView(post: post,
                                    width: width,
                                    displayGroup: displayGroup,
                                    zoomableImageInfo: $zoomableImageInfo,
                                    displayPostDetail: displayPostDetail,
                                    displayCommentDetail: displayCommentDetail,
                                    displayProfile: displayProfile,
                                    deletePost: deletePost,
                                    deleteComment: deleteComment,
                                    blockAuthor: blockAuthor,
                                    reactionTapped: reactionTapped,
                                    commentReactionTapped: commentReactionTapped,
                                    voteOnPoll: voteOnPoll,
                                    displayContentModeration: displayContentModeration,
                                    displayClientObject: displayClientObject)
                        .contentShape(Rectangle())
                        .onAppear { post.displayEvents.onAppear() }
                        .onDisappear { post.displayEvents.onDisappear() }
                        .modify {
                            if #available(iOS 17.0, *) {
                                $0.geometryGroup()
                            } else {
                                $0
                            }
                        }
                }
                if hasMoreData {
                    Compat.ProgressView()
                        .frame(width: 100)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .onAppear {
                            if #available(iOS 14, *) { Logger.posts.trace("Loader appeared, loading previous items...") }
                            loadPreviousItems()
                        }
                }
            }
            .readWidth($width)
        } else {
            emptyPostView
        }
    }
}
