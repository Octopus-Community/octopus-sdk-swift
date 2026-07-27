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
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    @State private var zoomableImageInfo: ZoomableImageInfo?
    @State private var isScrollingDown = false

    init(octopus: OctopusSDK, groupId: String, mainFlowPath: MainFlowPath,
         translationStore: ContentTranslationPreferenceStore,
         canClose: Bool = false, origin: GroupDetailNavigationOrigin = .sdk,
         navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: GroupDetailViewModel(
            octopus: octopus, groupId: groupId, mainFlowPath: mainFlowPath,
            translationStore: translationStore, origin: origin))
        self.mainFlowPath = mainFlowPath
        self.canClose = canClose
        self.navBarLeadingAction = navBarLeadingAction
    }

    var body: some View {
        ContentView(
            group: viewModel.group,
            groupNotFound: viewModel.groupNotFound,
            groupAccessLost: viewModel.groupAccessLost,
            onAccessDeniedTap: {
                viewModel.octopus.groupAccessDeniedCallback?(viewModel.groupId)
            },
            scrollToTop: $viewModel.scrollToTop,
            refresh: viewModel.refresh,
            isScrollingDown: $isScrollingDown) {
                postFeedView
            }
            .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
            .toastContainer(octopus: viewModel.octopus)
            .modify {
                if #available(iOS 15.0, *) {
                    $0.safeAreaInset(edge: .bottom, content: {
                        if !viewModel.groupAccessLost {
                            AuthorActionView(
                                octopus: viewModel.octopus, actionKind: .post,
                                displayCreateButton: viewModel.canCreateAnyPost,
                                isScrollingDown: isScrollingDown,
                                userProfileTapped: {
                                    if viewModel.ensureConnected(action: .viewOwnProfile) {
                                        dispatchCurrentUserActivityTap(octopus: viewModel.octopus,
                                                                      navigator: navigator)
                                    }
                                },
                                actionTapped: {
                                    navigator.push(.createPost(withPoll: false, defaultTopicId: viewModel.group?.id))
                                })
                            .accessibilitySortPriority(1)
                        }
                    })
                } else {
                    $0.overlay(
                        Group {
                            if !viewModel.groupAccessLost {
                                AuthorActionView(
                                    octopus: viewModel.octopus, actionKind: .post,
                                    displayCreateButton: viewModel.canCreateAnyPost,
                                    isScrollingDown: isScrollingDown,
                                    userProfileTapped: {
                                        if viewModel.ensureConnected(action: .viewOwnProfile) {
                                            dispatchCurrentUserActivityTap(octopus: viewModel.octopus,
                                                                          navigator: navigator)
                                        }
                                    },
                                    actionTapped: {
                                        navigator.push(.createPost(withPoll: false, defaultTopicId: viewModel.group?.id))
                                    })
                            }
                        },
                        alignment: .bottomTrailing)
                }
            }
            .largeScreenMarginBackground()
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

    @ViewBuilder
    private func leadingBarItem(group: GroupDetail?) -> some View {
        if let navBarLeadingAction {
            NavBarLeadingActionButton(navBarLeadingAction)
        } else if canClose {
            CloseButton(action: { presentationMode.wrappedValue.dismiss() })
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func trailingBarItem(group: GroupDetail?) -> some View {
        if let group, !viewModel.groupAccessLost {
            FollowGroupButton(canChangeFollowStatus: group.canChangeFollowStatus, isFollowed: group.isFollowed,
                              toggleFollow: viewModel.toggleFollowGroup)
        }
    }

}

private struct ContentView<PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let group: GroupDetail?
    let groupNotFound: Bool
    let groupAccessLost: Bool
    let onAccessDeniedTap: () -> Void
    @Binding var scrollToTop: Bool
    let refresh: @Sendable () async -> Void
    @Binding var isScrollingDown: Bool

    @ViewBuilder let postsView: PostsView

    var body: some View {
        VStack(spacing: 0) {
            // On iOS 26 the navigation bar uses its default translucent (glass) behavior (OCT-1532).
            Compat.ScrollView(
                showIndicators: false,
                scrollToTop: $scrollToTop,
                refreshAction: refresh) {
                    Compat.LazyVStack(spacing: 0) {
                        if let group {
                            GroupDetailHeaderView(group: group)

                            if groupAccessLost {
                                GroupAccessLostView(onTap: onAccessDeniedTap)
                                    .padding(.top, 80)
                            } else {
                                theme.colors.gray300.frame(height: 1)
                                postsView
                            }
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
                    .scrollDirectionAnchor()
                    .constrainedContentColumn()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .postsVisibilityScrollView()
                .onScrollDirectionChange(isScrollingDown: $isScrollingDown)
        }
    }
}

private struct GroupAccessLostView: View {
    @Environment(\.octopusTheme) private var theme
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Group.Permissions.AccessDenied.Text", bundle: .module)
                .font(theme.fonts.body1)
                .foregroundColor(theme.colors.gray700)
                .multilineTextAlignment(.center)
            Button(action: onTap) {
                Text("Group.Permissions.AccessDenied.Button", bundle: .module)
            }
            .buttonStyle(OctopusButtonStyle(.mid, style: .outline,
                                            externalTopPadding: 8, externalBottomPadding: 8))
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GroupDetailHeaderView: View {
    @Environment(\.octopusTheme) private var theme
    let group: GroupDetail

    @State private var displayFullDesc = false

    private var description: EllipsizableText { group.description }

    var body: some View {
        if group.description.fullText.nilIfEmpty != nil || group.customAction != nil {
            VStack(alignment: .leading, spacing: 0) {
                if description.fullText.nilIfEmpty != nil {
                    Group {
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
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let customAction = group.customAction {
                    GroupCTAContentView(groupId: group.id, cta: customAction, topPadding: 16)
                }
            }
            .padding(.bottom, 16)
        }
    }
}
