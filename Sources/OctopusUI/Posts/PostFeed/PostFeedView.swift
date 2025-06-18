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
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: PostFeedViewModel

    @Binding var zoomableImageInfo: ZoomableImageInfo?

    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool) -> Void
    let displayProfile: (String) -> Void
    let displayContentModeration: (String) -> Void

    @ViewBuilder var emptyPostView: EmptyPostView

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(viewModel: PostFeedViewModel,
         zoomableImageInfo: Binding<ZoomableImageInfo?>,
         displayPostDetail: @escaping (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool) -> Void,
         displayProfile: @escaping (String) -> Void,
         displayContentModeration: @escaping (String) -> Void,
         @ViewBuilder _ emptyPostView: () -> EmptyPostView){
        _viewModel = Compat.StateObject(wrappedValue: viewModel)
        _zoomableImageInfo = zoomableImageInfo
        self.displayPostDetail = displayPostDetail
        self.displayProfile = displayProfile
        self.displayContentModeration = displayContentModeration
        self.emptyPostView = emptyPostView()
    }

    var body: some View {
        ZStack {
            ContentView(
                posts: viewModel.posts, hasMoreData: viewModel.hasMoreData,
                zoomableImageInfo: $zoomableImageInfo,
                loadPreviousItems: viewModel.loadPreviousItems,
                displayPostDetail: displayPostDetail,
                displayProfile: displayProfile,
                deletePost: viewModel.deletePost(postId:),
                toggleLike: viewModel.toggleLike(postId:),
                voteOnPoll: viewModel.vote(pollAnswerId:postId:),
                displayContentModeration: {
                    if viewModel.ensureConnected() {
                        displayContentModeration($0)
                    }
                },
                emptyPostView: { emptyPostView }
            )
            if viewModel.isDeletingPost {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Done", bundle: .module),
                    isPresented: $viewModel.postDeleted, actions: { })
            } else {
                $0.alert(isPresented: $viewModel.postDeleted) {
                    Alert(title: Text("Post.Delete.Done", bundle: .module))
                }
            }
        }
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
    }
}

private struct ContentView<EmptyPostView: View>: View {
    let posts: [DisplayablePost]?
    let hasMoreData: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousItems: () -> Void
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool) -> Void
    let displayProfile: (String) -> Void
    let deletePost: (String) -> Void
    let toggleLike: (String) -> Void
    let voteOnPoll: (String, String) -> Bool
    let displayContentModeration: (String) -> Void
    @ViewBuilder var emptyPostView: EmptyPostView

    var body: some View {
        Group {
            if let posts {
                PostsView(posts: posts, hasMoreData: hasMoreData,
                          zoomableImageInfo: $zoomableImageInfo,
                          loadPreviousItems: loadPreviousItems,
                          displayPostDetail: displayPostDetail,
                          displayProfile: displayProfile,
                          deletePost: deletePost, toggleLike: toggleLike, voteOnPoll: voteOnPoll,
                          displayContentModeration: displayContentModeration,
                          emptyPostView: { emptyPostView })
            } else {
                Compat.ProgressView()
                    .frame(width: 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PostsView<EmptyPostView: View>: View {
    let posts: [DisplayablePost]
    let hasMoreData: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let loadPreviousItems: () -> Void
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool) -> Void
    let displayProfile: (String) -> Void
    let deletePost: (String) -> Void
    let toggleLike: (String) -> Void
    let voteOnPoll: (String, String) -> Bool
    let displayContentModeration: (String) -> Void
    @ViewBuilder var emptyPostView: EmptyPostView

    @State private var width: CGFloat = 0

    var body: some View {
        if !posts.isEmpty {
            Compat.LazyVStack {
                ForEach(posts, id: \.uuid) { post in
                    PostSummaryView(post: post, width: width,
                                    zoomableImageInfo: $zoomableImageInfo,
                                    displayPostDetail: displayPostDetail,
                                    displayProfile: displayProfile, deletePost: deletePost,
                                    toggleLike: toggleLike, voteOnPoll: voteOnPoll,
                                    displayContentModeration: displayContentModeration)
                        .contentShape(Rectangle())
                        .onAppear { post.displayEvents.onAppear() }
                        .onDisappear() { post.displayEvents.onDisappear() }
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
