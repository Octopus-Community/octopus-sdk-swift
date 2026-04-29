//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore
import os

struct GroupDetailView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.trackingApi) var trackingApi
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    @Compat.StateObject private var viewModel: GroupDetailViewModel

    private let mainFlowPath: MainFlowPath
    private let canClose: Bool

    @State private var zoomableImageInfo: ZoomableImageInfo?

    init(octopus: OctopusSDK, groupId: String, mainFlowPath: MainFlowPath,
         translationStore: ContentTranslationPreferenceStore,
         canClose: Bool = false, origin: GroupDetailNavigationOrigin = .sdk) {
        _viewModel = Compat.StateObject(wrappedValue: GroupDetailViewModel(
            octopus: octopus, groupId: groupId, mainFlowPath: mainFlowPath,
            translationStore: translationStore, origin: origin))
        self.mainFlowPath = mainFlowPath
        self.canClose = canClose
    }

    var body: some View {
        ContentView(
            group: viewModel.group,
            groupNotFound: viewModel.groupNotFound,
            scrollToTop: $viewModel.scrollToTop,
            refresh: viewModel.refresh) {
                postFeedView
            }
            .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
            .toastContainer(octopus: viewModel.octopus)
            .modify {
                if #available(iOS 15.0, *) {
                    $0.safeAreaInset(edge: .bottom, content: {
                        AuthorActionView(
                            octopus: viewModel.octopus, actionKind: .post,
                            userProfileTapped: {
                                if viewModel.ensureConnected(action: .viewOwnProfile) {
                                    navigator.push(.currentUserProfile)
                                }
                            },
                            actionTapped: {
                                navigator.push(.createPost(withPoll: false, defaultTopic: viewModel.group?.coreTopic))
                            })
                        .accessibilitySortPriority(1)
                    })
                } else {
                    $0.overlay(
                        AuthorActionView(
                            octopus: viewModel.octopus, actionKind: .post,
                            userProfileTapped: {
                                if viewModel.ensureConnected(action: .viewOwnProfile) {
                                    navigator.push(.currentUserProfile)
                                }
                            },
                            actionTapped: {
                                navigator.push(.createPost(withPoll: false, defaultTopic: viewModel.group?.coreTopic))
                            }),
                        alignment: .bottomTrailing)
                }
            }
            .zoomableImageContainer(
                zoomableImageInfo: $zoomableImageInfo,
                defaultLeadingBarItem: leadingBarItem(group: viewModel.group),
                defaultTrailingBarItem: trailingBarItem(group: viewModel.group),
                defaultTrailingSharedBackgroundVisibility: .hidden,
                defaultNavigationBarTitle: Text(viewModel.group?.name ?? "")
            )
            .errorAlert(viewModel.$error)
            .emitScreenDisplayed(
                .groupDetail(.init(groupId: viewModel.groupId, source: viewModel.analyticsSource)),
                trackingApi: trackingApi)
    }

    @ViewBuilder
    private var postFeedView: some View {
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

    @ViewBuilder
    private func leadingBarItem(group: GroupDetail?) -> some View {
        if canClose {
            CloseButton(action: { presentationMode.wrappedValue.dismiss() })
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func trailingBarItem(group: GroupDetail?) -> some View {
        if let group {
            FollowGroupButton(canChangeFollowStatus: group.canChangeFollowStatus, isFollowed: group.isFollowed,
                              toggleFollow: viewModel.toggleFollowGroup)
        }
    }

}

private struct ContentView<PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let group: GroupDetail?
    let groupNotFound: Bool
    @Binding var scrollToTop: Bool
    let refresh: @Sendable () async -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        VStack(spacing: 0) {
#if compiler(>=6.2)
            // Disable nav bar opacity on iOS 26 to have the same behavior as before.
            // TODO: See with product team if we need to keep it.
            if #available(iOS 26.0, *) {
                Color.white.opacity(0.0001)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
#endif
            Compat.ScrollView(
                showIndicators: false,
                scrollToTop: $scrollToTop,
                refreshAction: refresh) {
                    Compat.LazyVStack(spacing: 0) {
                        if let group {
                            if group.description.fullText.nilIfEmpty != nil {
                                GroupDetailContentView(group: group)
                                theme.colors.gray300.frame(height: 1)
                            }

                            postsView
                        } else if groupNotFound {
                            VStack {
                                Image(uiImage: theme.assets.icons.content.post.notAvailable)
                                    .accessibilityHidden(true)
                                Text("Content.Detail.NotAvailable", bundle: .module)
                                    .font(theme.fonts.body2)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(theme.colors.gray500)
                        } else {
                            VStack {
                                Spacer()
                                Compat.ProgressView()
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .postsVisibilityScrollView()
        }
    }
}

private struct GroupDetailContentView: View {
    @Environment(\.octopusTheme) private var theme
    let group: GroupDetail

    @State private var displayFullDesc = false

    private var description: EllipsizableText { group.description }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if description.isEllipsized {
                Text(verbatim: "\(description.getText(ellipsized: !displayFullDesc))\(!displayFullDesc ? "... " : " ")")
                +
                Text(displayFullDesc ? "Common.ReadLess" : "Common.ReadMore", bundle: .module)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.gray500)
            } else {
                Text(description.fullText)
            }
        }
        .font(theme.fonts.body2)
        .foregroundColor(theme.colors.gray900)
        .multilineTextAlignment(.leading)
        .onTapGesture {
            withAnimation {
                displayFullDesc.toggle()
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
