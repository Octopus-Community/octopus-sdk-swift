//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus
import OctopusCore

struct PostListView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: PostListViewModel

    @State private var noConnectedReplacementAction: ConnectedActionReplacement?

    @Binding var selectedRootFeed: RootFeed?
    @Binding private var zoomableImageInfo: ZoomableImageInfo?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, selectedRootFeed: Binding<RootFeed?>, zoomableImageInfo: Binding<ZoomableImageInfo?>) {
        _viewModel = Compat.StateObject(wrappedValue: PostListViewModel(octopus: octopus, mainFlowPath: mainFlowPath))
        _selectedRootFeed = selectedRootFeed
        _zoomableImageInfo = zoomableImageInfo
    }

    var body: some View {
        ZStack {
            ContentView(
                scrollToTop: $viewModel.scrollToTop,
                refresh: viewModel.refresh) {
                    if let postFeedViewModel = viewModel.postFeedViewModel {
                        PostFeedView(
                            viewModel: postFeedViewModel,
                            zoomableImageInfo: $zoomableImageInfo,
                            displayPostDetail: {
                                navigator.push(.postDetail(postId: $0, comment: $1, commentToScrollTo: nil,
                                                           scrollToMostRecentComment: $2))
                            },
                            displayProfile: { profileId in
                                if #available(iOS 14, *) { Logger.profile.trace("Display profile \(profileId)") }
                                if profileId == viewModel.thisUserProfileId {
                                    navigator.push(.currentUserProfile)
                                } else {
                                    navigator.push(.publicProfile(profileId: profileId))
                                }
                            },
                            displayContentModeration: {
                                navigator.push(.reportContent(contentId: $0))
                            }) {
                                DefaultEmptyPostsView()
                            }
                    } else {
                        EmptyView()
                    }
                }
                .id(viewModel.postFeedViewModel?.feed.id) // rebuild the content if feedId changes (makes scroll view goes to top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
        .modify {
            if #available(iOS 15.0, *) {
                $0.safeAreaInset(edge: .bottom, content: {
                    AuthorActionView(
                        octopus: viewModel.octopus, actionKind: .post,
                        userProfileTapped: {
                            if viewModel.ensureConnected() {
                                navigator.push(.currentUserProfile)
                            }
                        },
                        actionTapped: viewModel.createPostTapped)
                })
            } else {
                $0.overlay(
                    AuthorActionView(octopus: viewModel.octopus, actionKind: .post,
                                     userProfileTapped: {
                                         if viewModel.ensureConnected() {
                                             navigator.push(.currentUserProfile)
                                         }
                                     },
                                     actionTapped: viewModel.createPostTapped),
                    alignment: .bottomTrailing)
            }
        }
        .fullScreenCover(isPresented: $viewModel.openCreatePost) {
            CreatePostView(octopus: viewModel.octopus)
        }
        .onValueChanged(of: selectedRootFeed) {
            guard let selectedRootFeed = $0 else { return }
            viewModel.set(feed: selectedRootFeed.feed)
        }
        .onAppear() {
            guard let selectedRootFeed = selectedRootFeed else { return }
            viewModel.set(feed: selectedRootFeed.feed)
        }
    }
}

private struct ContentView<PostsView: View>: View {
    @Binding var scrollToTop: Bool
    let refresh: @Sendable () async -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        Compat.ScrollView(
            showIndicators: false,
            scrollToTop: $scrollToTop,
            refreshAction: refresh) {
                postsView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
