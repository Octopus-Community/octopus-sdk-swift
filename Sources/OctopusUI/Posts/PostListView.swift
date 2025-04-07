//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus
import OctopusCore

struct PostListView: View {
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: PostListViewModel

    // TODO: remove this. It is temporary handling the isLoggedIn just in case the product team ask it again
    @State private var loggedInDone: Bool = false

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var displayPostDetailId: String?
    @State private var displayMostRecentComment = false
    @State private var displayPostDetail = false

    @State private var displayProfileId: String?
    @State private var displayProfile = false

    @State private var displayModerateId: String?
    @State private var displayContentModeration = false

    @State private var openRoute: PostListRoute?

    // TODO: Delete when router is fully used
    @State private var displaySSOError = false
    @State private var displayableSSOError: DisplayableString?

    @Binding var selectedRootFeed: RootFeed?

    init(octopus: OctopusSDK, selectedRootFeed: Binding<RootFeed?>) {
        _viewModel = Compat.StateObject(wrappedValue: PostListViewModel(octopus: octopus))
        _selectedRootFeed = selectedRootFeed
    }

    var body: some View {
        ZStack {
            ContentView(
                scrollToTop: $viewModel.scrollToTop,
                refresh: viewModel.refresh) {
                    if let postFeedViewModel = viewModel.postFeedViewModel {
                        PostFeedView(
                            viewModel: postFeedViewModel,
                            displayPostDetail: {
                                displayPostDetailId = $0
                                displayMostRecentComment = $1
                                displayPostDetail = true
                            },
                            displayProfile: { profileId in
                                if #available(iOS 14, *) { Logger.profile.trace("Display profile \(profileId)") }
                                if profileId == viewModel.thisUserProfileId {
                                    openRoute = .currentUserProfile
                                } else {
                                    displayProfileId = profileId
                                    displayProfile = true
                                }
                            },
                            displayContentModeration: {
                                displayModerateId = $0
                                displayContentModeration = true
                            }) {
                                DefaultEmptyPostsView()
                            }
                    } else {
                        EmptyView()
                    }
                }
                .id(viewModel.postFeedViewModel?.feed.id) // rebuild the content if feedId changes (makes scroll view goes to top)
//            NavigationLink(destination: CurrentUserProfileSummaryView(octopus: viewModel.octopus,
//                                                                      dismiss: !$viewModel.openUserProfile),
//                           isActive: $viewModel.openUserProfile) {
//                EmptyView()
//            }.hidden()
            NavigationLink(destination:
                Group {
                    if let displayPostDetailId {
                        PostDetailView(octopus: viewModel.octopus, postUuid: displayPostDetailId,
                                       scrollToMostRecentComment: displayMostRecentComment)
                    } else {
                        EmptyView()
                    }
            }, isActive: $displayPostDetail) {
                EmptyView()
            }.hidden()
            NavigationLink(
                destination: Group {
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
                    if let displayModerateId {
                        ReportView(octopus: viewModel.octopus,
                                       context: .content(contentId: displayModerateId))
                    } else { EmptyView() }
                },
                isActive: $displayContentModeration) {
                    EmptyView()
                }.hidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .postListViewRouter(octopus: viewModel.octopus, openRoute: $openRoute, loggedInDone: $loggedInDone)
        .modify {
            if #available(iOS 15.0, *) {
                $0.safeAreaInset(edge: .bottom, content: {
                    AuthorActionView(octopus: viewModel.octopus, actionKind: .post,
                                     userProfileTapped: { openRoute = .currentUserProfile },
                                     actionTapped: viewModel.createPostTapped)
                })
            } else {
                $0.overlay(
                    AuthorActionView(octopus: viewModel.octopus, actionKind: .post,
                                     userProfileTapped: { openRoute = .currentUserProfile },
                                     actionTapped: viewModel.createPostTapped),
                    alignment: .bottomTrailing)
            }
        }
        .fullScreenCover(isPresented: $viewModel.openCreatePost) {
            CreatePostView(octopus: viewModel.octopus)
        }
        .fullScreenCover(isPresented: $viewModel.openLogin) {
            MagicLinkView(octopus: viewModel.octopus, isLoggedIn: $loggedInDone)
                .environment(\.dismissModal, $viewModel.openLogin)
        }
        .fullScreenCover(isPresented: $viewModel.openCreateProfile) {
            NavigationView {
                CreateProfileView(octopus: viewModel.octopus, isLoggedIn: $loggedInDone)
                    .environment(\.dismissModal, $viewModel.openCreateProfile)
            }
            .navigationBarHidden(true)
            .accentColor(theme.colors.primary)
        }
        .onValueChanged(of: selectedRootFeed) {
            guard let selectedRootFeed = $0 else { return }
            viewModel.set(feed: selectedRootFeed.feed)
        }
        .onAppear() {
            guard let selectedRootFeed = selectedRootFeed else { return }
            viewModel.set(feed: selectedRootFeed.feed)
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
