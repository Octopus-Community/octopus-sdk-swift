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
    @Environment(\.trackingApi) var trackingApi
    @Compat.StateObject private var viewModel: PostListViewModel

    @Binding var selectedRootFeed: RootFeed?
    @Binding private var zoomableImageInfo: ZoomableImageInfo?
    @Binding private var isScrollingDown: Bool

    @State private var lastScreenFeedIdSent: String?

    private let mainFlowPath: MainFlowPath
    private let topContentInset: CGFloat

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         selectedRootFeed: Binding<RootFeed?>, zoomableImageInfo: Binding<ZoomableImageInfo?>,
         isScrollingDown: Binding<Bool> = .constant(false),
         topContentInset: CGFloat = 0) {
        _viewModel = Compat.StateObject(wrappedValue: PostListViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath, translationStore: translationStore))
        _selectedRootFeed = selectedRootFeed
        _zoomableImageInfo = zoomableImageInfo
        _isScrollingDown = isScrollingDown
        self.mainFlowPath = mainFlowPath
        self.topContentInset = topContentInset
    }

    var body: some View {
        ZStack {
            ContentView(
                scrollToTop: $viewModel.scrollToTop,
                refresh: viewModel.refresh,
                isScrollingDown: $isScrollingDown,
                topContentInset: topContentInset) {
                    if let postFeedViewModel = viewModel.postFeedViewModel {
                        PostFeedView(
                            viewModel: postFeedViewModel,
                            zoomableImageInfo: $zoomableImageInfo,
                            displayPostDetail: {
                                if !$1 && !$2 && $3 == nil {
                                    trackingApi.emit(event: .postClicked(.init(postId: $0, coreSource: .feed)))
                                }
                                navigator.push(.postDetail(postId: $0, comment: $1, commentToScrollTo: $3,
                                                           scrollToMostRecentComment: $2, origin: .sdk,
                                                           hasFeaturedComment: $4))
                            },
                            displayCommentDetail: {
                                navigator.push(.commentDetail(
                                    commentId: $0, displayGoToParentButton: false, reply: $1, replyToScrollTo: nil))
                            },
                            displayProfile: { profileId, clientUserId in
                                if #available(iOS 14, *) { Logger.profile.trace("Display profile \(profileId)") }
                                dispatchProfileTap(octopus: viewModel.octopus, navigator: navigator,
                                                   profileId: profileId, clientUserId: clientUserId)
                            },
                            openGroup: { navigator.push(.groupDetail(groupId: $0)) },
                            displayContentModeration: {
                                mainFlowPath.reportTarget = .content(contentId: $0)
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
        .toastContainer(octopus: viewModel.octopus)
        .modify {
            if #available(iOS 15.0, *) {
                $0.safeAreaInset(edge: .bottom, content: {
                    AuthorActionView(
                        octopus: viewModel.octopus, actionKind: .post,
                        displayCreateButton: viewModel.canCreatePost,
                        isScrollingDown: isScrollingDown,
                        userProfileTapped: {
                            if viewModel.ensureConnected(action: .viewOwnProfile) {
                                dispatchCurrentUserActivityTap(octopus: viewModel.octopus, navigator: navigator)
                            }
                        },
                        actionTapped: {
                            navigator.push(.createPost(withPoll: false, defaultTopicId: nil))
                        })
                    .accessibilitySortPriority(1)
                })
            } else {
                $0.overlay(
                    AuthorActionView(octopus: viewModel.octopus, actionKind: .post,
                                     displayCreateButton: viewModel.canCreatePost,
                                     isScrollingDown: isScrollingDown,
                                     userProfileTapped: {
                                         if viewModel.ensureConnected(action: .viewOwnProfile) {
                                             dispatchCurrentUserActivityTap(octopus: viewModel.octopus,
                                                                           navigator: navigator)
                                         }
                                     },
                                     actionTapped: {
                                         navigator.push(.createPost(withPoll: false, defaultTopicId: nil))
                                     }),
                    alignment: .bottomTrailing)
            }
        }
        .largeScreenMarginBackground()
        .onValueChanged(of: selectedRootFeed) {
            guard let selectedRootFeed = $0 else { return }
            viewModel.set(feed: selectedRootFeed.feed)
            if lastScreenFeedIdSent != selectedRootFeed.feedId {
                trackingApi.emit(event: .screenDisplayed(.mainFeed(.init(feedId: selectedRootFeed.feedId))))
                lastScreenFeedIdSent = selectedRootFeed.feedId
            }

        }
        .onAppear {
            guard let selectedRootFeed = selectedRootFeed else { return }
            viewModel.set(feed: selectedRootFeed.feed)
            if lastScreenFeedIdSent != selectedRootFeed.feedId {
                trackingApi.emit(event: .screenDisplayed(.mainFeed(.init(feedId: selectedRootFeed.feedId))))
                lastScreenFeedIdSent = selectedRootFeed.feedId
            }
        }
    }
}

private struct ContentView<PostsView: View>: View {
    @Binding var scrollToTop: Bool
    let refresh: @Sendable () async -> Void
    @Binding var isScrollingDown: Bool
    let topContentInset: CGFloat

    @ViewBuilder let postsView: PostsView

    var body: some View {
        Compat.ScrollView(
            showIndicators: false,
            scrollToTop: $scrollToTop,
            refreshAction: refresh) {
                postsView
                    .padding(.top, topContentInset)
                    .scrollDirectionAnchor()
                    .constrainedContentColumn()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .postsVisibilityScrollView()
            .onScrollDirectionChange(isScrollingDown: $isScrollingDown)
    }
}
