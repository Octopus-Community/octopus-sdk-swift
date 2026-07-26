//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ProfileSummaryView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.trackingApi) var trackingApi
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: ProfileSummaryViewModel

    @State private var displayBlockUserAlert = false

    @State private var openActions = false

    @State private var noConnectedReplacementAction: ConnectedActionReplacement?

    @State private var zoomableImageInfo: ZoomableImageInfo?

    private let mainFlowPath: MainFlowPath
    private let canClose: Bool
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         profileId: String, canClose: Bool = false, navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: ProfileSummaryViewModel(
            octopus: octopus, translationStore: translationStore, profileId: profileId))
        self.mainFlowPath = mainFlowPath
        self.canClose = canClose
        self.navBarLeadingAction = navBarLeadingAction
    }

    var body: some View {
        VStack {
            ContentView(profile: viewModel.profile,
                        displayAccountAge: viewModel.displayAccountAge,
                        zoomableImageInfo: $zoomableImageInfo, refresh: viewModel.refresh) {
                if let postFeedViewModel = viewModel.postFeedViewModel {
                    PostFeedView(
                        viewModel: postFeedViewModel,
                        zoomableImageInfo: $zoomableImageInfo,
                        displayPostDetail: {
                            if !$1 && !$2 && $3 == nil {
                                trackingApi.emit(event: .postClicked(.init(postId: $0, coreSource: .profile)))
                            }
                            navigator.push(.postDetail(postId: $0, comment: $1, commentToScrollTo: $3,
                                                       scrollToMostRecentComment: $2, origin: .sdk,
                                                       hasFeaturedComment: $4))
                        },
                        displayCommentDetail: {
                            navigator.push(.commentDetail(
                                commentId: $0, displayGoToParentButton: false, reply: $1, replyToScrollTo: nil))
                        },
                        displayProfile: { _, _ in },
                        openGroup: { navigator.push(.groupDetail(groupId: $0)) },
                        displayContentModeration: {
                            mainFlowPath.reportTarget = .content(contentId: $0)
                        }) {
                            OtherUserEmptyPostView()
                        }
                } else {
                    EmptyView()
                }
            }
        }
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarTitle: Text("Profile.Title", bundle: .module))
        .toastContainer(octopus: viewModel.octopus)
        .errorAlert(viewModel.$error)
        .emitScreenDisplayed(.otherUserProfile(.init(profileId: viewModel.profileId)), trackingApi: trackingApi)
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            presentationMode.wrappedValue.dismiss()
        }
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: actionSheetButtons)
        }
        .destructiveConfirmationAlert(
            "Block.Profile.Alert.Title",
            isPresented: $displayBlockUserAlert,
            destructiveLabel: "Common.Continue",
            action: viewModel.blockUser,
            message: "Block.Profile.Alert.Message")
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Block.Profile.Done.Title", bundle: .module),
                    isPresented: $viewModel.blockUserDone, actions: {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $viewModel.blockUserDone) {
                    Alert(title: Text("Block.Profile.Done.Title", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        presentationMode.wrappedValue.dismiss()
                    }))
                }
            }
        }
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
    }

    private var actionSheetButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        buttons.append(.destructive(Text("Moderation.Profile.Button", bundle: .module)) {
            guard viewModel.ensureConnected(action: .moderation) else { return }
            mainFlowPath.reportTarget = .profile(profileId: viewModel.profileId)
        })
        if viewModel.profile?.canBeBlocked == true {
            buttons.append(.destructive(Text("Block.Profile.Button", bundle: .module)) {
                guard viewModel.ensureConnected(action: .blockUser) else { return }
                displayBlockUserAlert = true
            })
        }
        buttons.append(.cancel())
        return buttons
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if let navBarLeadingAction {
            NavBarLeadingActionButton(navBarLeadingAction)
        } else if canClose {
            CloseButton(action: { presentationMode.wrappedValue.dismiss() })
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                DestructiveMenuButton(action: {
                    guard viewModel.ensureConnected(action: .moderation) else { return }
                    mainFlowPath.reportTarget = .profile(profileId: viewModel.profileId)
                }) {
                    Label(title: { Text("Moderation.Profile.Button", bundle: .module) },
                          icon: { Image(uiImage: theme.assets.icons.profile.report) })
                }
                if viewModel.profile?.canBeBlocked == true {
                    DestructiveMenuButton(action: {
                        guard viewModel.ensureConnected(action: .blockUser) else { return }
                        displayBlockUserAlert = true
                    }) {
                        Label(title: { Text("Block.Profile.Button", bundle: .module) },
                              icon: { Image(uiImage: theme.assets.icons.profile.blockUser) })
                    }
                }
            }, label: {
                if #available(iOS 26.0, *) {
                    Label(title: { Text("Settings.Community.Title", bundle: .module) },
                          icon: { Image(uiImage: theme.assets.icons.common.moreActions) })
                } else {
                    Image(uiImage: theme.assets.icons.common.moreActions)
                        .font(theme.fonts.navBarItem)
                        .padding(.vertical)
                        .padding(.leading)
                        .frame(minWidth: 44, minHeight: 44)
                }
            })
            .buttonStyle(.plain)
        } else {
            Button(action: { openActions = true }) {
                Image(uiImage: theme.assets.icons.common.moreActions)
                    .padding(.vertical)
                    .padding(.leading)
                    .font(theme.fonts.navBarItem)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ContentView<PostsView: View>: View {
    let profile: DisplayableProfile?
    let displayAccountAge: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        if let profile {
            VStack(spacing: 0) {
                // On iOS 26 the navigation bar uses its default translucent (glass) behavior (OCT-1532).
                ProfileContentView(
                    profile: profile,
                    displayAccountAge: displayAccountAge,
                    zoomableImageInfo: $zoomableImageInfo, refresh: refresh) {
                        postsView
                }
                PoweredByOctopusView()
            }
            .largeScreenMarginBackground()
        } else {
            Compat.ProgressView()
        }
    }
}

private struct ProfileContentView<PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: DisplayableProfile
    let displayAccountAge: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void
    @ViewBuilder let postsView: PostsView

    @State private var selectedTab = 0

    @State private var displayFullBio = false
    @State private var displayStickyHeader = false

    private let scrollViewCoordinateSpace = "otherUserProfileScrollViewCoordinateSpace"

    var body: some View {
        Compat.ScrollView(refreshAction: refresh) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 16) {
                        ZoomableAuthorAvatarView(avatar: avatar, zoomableImageInfo: $zoomableImageInfo)
                            .frame(width: 71, height: 71)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.nickname ?? "")
                                .font(theme.fonts.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.colors.gray900)
                                .modify {
                                    if #available(iOS 15.0, *) {
                                        $0.textSelection(.enabled)
                                    } else { $0 }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if profile.tags.contains(.admin) {
                                Text("Profile.Tag.Admin", bundle: .module)
                                    .octopusBadgeStyle(.xs, status: .admin)
                            } else {
                                GamificationLevelBadge(level: profile.gamificationLevel, size: .big)
                            }
                        }
                    }

                    Spacer().frame(height: 16)

                    ProfileCounterView(totalMessages: profile.totalMessages,
                                       accountCreationDate: displayAccountAge ? profile.accountCreationDate : nil)

                    if let bio = profile.bio {
                        Group {
                            if bio.isEllipsized {
                                Text(verbatim: "\(bio.getText(ellipsized: !displayFullBio))\(!displayFullBio ? "... " : " ")")
                                +
                                Text(displayFullBio ? "Common.ReadLess" : "Common.ReadMore", bundle: .module)
                                    .fontWeight(.medium)
                                    .foregroundColor(theme.colors.gray500)
                            } else {
                                Text(bio.fullText)
                            }
                        }
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray900)
                        .modify {
                            if #available(iOS 15.0, *) {
                                $0.textSelection(.enabled)
                            } else { $0 }
                        }
                        .padding(.vertical, 5)
                        .onTapGesture {
                            withAnimation {
                                displayFullBio.toggle()
                            }
                        }
                    }
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)

                CustomSegmentedControl(tabs: ["Profile.Tabs.Posts"], tabCount: 3, selectedTab: $selectedTab)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onValueChanged(of: geometry.frame(in: .named(scrollViewCoordinateSpace))) { frame in
                                    if frame.minY <= 0, !displayStickyHeader {
                                        displayStickyHeader = true
                                    } else if frame.minY > 0, displayStickyHeader {
                                        displayStickyHeader = false
                                    }
                                }
                        }
                    )
                theme.colors.gray300.frame(height: 1)
                postsView
            }
            // Top gap moved inside the scroll content (was `.padding(.top, 8)` wrapping the whole
            // scroll view, which pinned it below the safe area and blocked the under-bar bleed).
            .padding(.top, 8)
            .constrainedContentColumn()
        }
        // Match the feed/group scroll views so the scroll owns the full region, including the space
        // behind the nav bar — the content then bleeds under the iOS 26 translucent (glass) bar.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: scrollViewCoordinateSpace)
        .postsVisibilityScrollView()
        // Pinned tab header as an overlay (not a ZStack sibling): an overlay renders inside the base
        // view's safe area, so it stays below the nav bar while the scroll view bleeds under it —
        // mirroring the feed's explore-bar overlay in MainRootFeedView.
        .overlay(stickyTabHeader, alignment: .top)
    }

    // Pinned tab header (mirrors CurrentUserProfileContentView): Instagram-style glass "pills" that
    // float over the blurred content scrolling under the translucent nav bar.
    @ViewBuilder
    private var stickyTabHeader: some View {
        if displayStickyHeader {
            ProfileStickyTabsHeader(tabs: ["Profile.Tabs.Posts"], selectedTab: $selectedTab)
        }
    }

    private var avatar: Author.Avatar {
        if let pictureUrl = profile.pictureUrl {
            return .image(url: pictureUrl, name: profile.nickname ?? "")
        } else {
            return .defaultImage(name: profile.nickname ?? "")
        }
    }
}
