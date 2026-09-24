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
                        loadFailure: viewModel.loadFailure,
                        retryFirstLoad: viewModel.retryFirstLoad,
                        displayAccountAge: viewModel.displayAccountAge,
                        zoomableImageInfo: $zoomableImageInfo,
                        refresh: viewModel.refresh,
                        showsCommentsTab: viewModel.showCommentsTab,
                        commentsView: { commentsView }) {
                if let postFeedViewModel = viewModel.postFeedViewModel {
                    PostFeedView(
                        screenStatePadding: ScreenState.profilePadding,
                        loaderTopPadding: 130,
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
                            ScreenState(
                                image: theme.assets.icons.screenStates.emptyContent,
                                title: .localizationKey("Profile.Posts.EmptyState.Other"),
                                verticalPadding: ScreenState.profilePadding)
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
        .toastContainer(octopus: viewModel.octopus,
                        retryFailedFetch: { Task { await viewModel.refresh() } })
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

    /// The Comments tab content. Reuses the same navigation closures (and `.postClicked`
    /// tracking) as the Posts tab above, so tapping into a comment/post behaves identically from either tab.
    @ViewBuilder
    private var commentsView: some View {
        if let commentsViewModel = viewModel.commentsViewModel {
            ProfileCommentsListView(
                viewModel: commentsViewModel,
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
                        commentId: $0, displayGoToParentButton: false, reply: $1, replyToScrollTo: $2))
                })
        }
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

private struct ContentView<CommentsView: View, PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme

    let profile: DisplayableProfile?
    let loadFailure: ScreenStateFailure?
    let retryFirstLoad: () -> Void
    let displayAccountAge: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void
    /// Whether the Comments tab should be shown (`showCommentsOnOtherProfiles`).
    let showsCommentsTab: Bool

    /// The Comments tab content.
    @ViewBuilder let commentsView: CommentsView
    @ViewBuilder let postsView: PostsView

    var body: some View {
        if let profile {
            VStack(spacing: 0) {
                // On iOS 26 the navigation bar uses its default translucent (glass) behavior.
                ProfileContentView(
                    profile: profile,
                    displayAccountAge: displayAccountAge,
                    zoomableImageInfo: $zoomableImageInfo, refresh: refresh,
                    showsCommentsTab: showsCommentsTab,
                    commentsView: { commentsView }) {
                        postsView
                }
                PoweredByOctopusView()
            }
            .largeScreenMarginBackground()
        } else if let loadFailure {
            loadFailure.screenState(verticalPadding: ScreenState.profilePadding,
                                    icons: theme.assets.icons, retry: retryFirstLoad)
        } else {
            Compat.ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 130)
        }
    }
}

private struct ProfileContentView<CommentsView: View, PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: DisplayableProfile
    let displayAccountAge: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void
    let showsCommentsTab: Bool
    @ViewBuilder let commentsView: CommentsView
    @ViewBuilder let postsView: PostsView

    @State private var selectedTab = 0

    @State private var displayFullBio = false
    @State private var displayStickyHeader = false
    /// Scroll offset shared by the inline tab row and the pinned pill row that replaces it.
    @State private var tabsScrollOffset: CGFloat = 0

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

                CustomSegmentedControl(tabs: tabs, selectedTab: $selectedTab,
                                       scrollOffset: $tabsScrollOffset)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onValueChanged(of: geometry.frame(in: .named(scrollViewCoordinateSpace))) { frame in
                                    let pinnedHeaderShows = frame.minY <= 0
                                    guard pinnedHeaderShows != displayStickyHeader else { return }
                                    withAnimation(ProfileTabsLayout.pinnedHeaderAnimation) {
                                        displayStickyHeader = pinnedHeaderShows
                                    }
                                }
                        }
                    )
                    .hiddenWhilePinnedHeaderShows(displayStickyHeader)
                theme.colors.gray300.frame(height: 1)
                    .hiddenWhilePinnedHeaderShows(displayStickyHeader)
                if selectedTab == 1 {
                    commentsView
                } else {
                    postsView
                }
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
        // If the Comments tab disappears (config flip / feed refused) while it's selected, fall back to
        // Posts rather than leaving the selection pointing at a now-hidden tab.
        .onValueChanged(of: showsCommentsTab) { showsCommentsTab in
            if !showsCommentsTab, selectedTab == 1 {
                selectedTab = 0
            }
        }
    }

    /// Posts(0) / Comments(1, gated by `showsCommentsTab`).
    private var tabs: [LocalizedStringKey] {
        showsCommentsTab ? ["Profile.Tabs.Posts", "Profile.Tabs.Comments"] : ["Profile.Tabs.Posts"]
    }

    // Pinned tab header (mirrors CurrentUserProfileContentView): Instagram-style glass "pills" that
    // float over the blurred content scrolling under the translucent nav bar.
    @ViewBuilder
    private var stickyTabHeader: some View {
        if displayStickyHeader {
            ProfileStickyTabsHeader(tabs: tabs, selectedTab: $selectedTab, scrollOffset: $tabsScrollOffset)
                .transition(.opacity)
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
