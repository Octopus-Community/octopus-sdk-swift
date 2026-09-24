//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

/// Whether the connected-user Activity screen's overflow menu can open the host's profile screen
/// (Unified Profile). **Both** the Unified Profile activation gate (see
/// ``unifiedProfileActive(exposeClientUserId:onNavigateToProfileWired:)``) **and** a reachable host
/// profile must hold: a non-guest member with a client user id. A guest, or a BO/admin-created
/// profile (neither has a client id), has no host profile to open even when the feature is active —
/// showing "View/Edit my profile" for them would dead-end. Pure so the gating stays unit-testable
/// independently of the SwiftUI view (mirrors ``unifiedProfileActive(exposeClientUserId:onNavigateToProfileWired:)``).
///
/// - Parameters:
///   - exposeClientUserId: whether the backend community config exposes client user ids.
///   - onNavigateToProfileWired: whether the host wired `onNavigateToProfileCallback`.
///   - isGuest: whether the connected user is a guest.
///   - connectedUserClientUserId: the connected user's own `clientUserId`, or `nil`.
func canOpenHostProfile(exposeClientUserId: Bool, onNavigateToProfileWired: Bool,
                        isGuest: Bool, connectedUserClientUserId: String?) -> Bool {
    unifiedProfileActive(exposeClientUserId: exposeClientUserId,
                         onNavigateToProfileWired: onNavigateToProfileWired)
        && !isGuest
        && connectedUserClientUserId != nil
}

extension ActivityTab {
    /// Index of this landing tab in the connected-user Activity screen's tab row, whose order is
    /// Notifications / Posts / Comments. Comments is never a landing tab, so it sits last
    /// without affecting either of the two that are.
    ///
    /// Pure so the mapping stays unit-testable, and single so the screen's two landing-tab paths (the
    /// synchronous floating-button seed and the asynchronous `connectedUserInitialTab`) can never
    /// disagree.
    var viewIndex: Int {
        switch self {
        case .notifications: 0
        case .posts: 1
        }
    }
}

/// The "activity" screen (Unified Profile). Polymorphic like Android's single
/// `ActivityScreen`, driven by the resolved ``ActivityMode``:
/// - **connected-user mode**: the connected user's own activity — a static "Activity" title, a
///   top-right overflow menu (profile · legal · report), and three tabs (Notifications, Posts,
///   Comments). No profile header, no gamification (that is exposed to the host via the read-only
///   community-data API instead). Opened by the home floating button
///   (`ActivitySource.connectedUser`), or when a profileId / clientUserId entry point resolves to the
///   connected user's own id.
/// - **other-user mode**: another member's content, with no header and no overflow menu — the
///   in-community profile-tap path (`ActivitySource.profileId`) or the `OctopusInitialScreen.activity`
///   host entry point (`ActivitySource.clientUserId`). Posts only under a "{nickname}'s Posts" title,
///   or Posts + Comments tabs under "{nickname}'s Activity" when the community exposes another
///   member's comments, exactly like `ProfileSummaryView`.
///
/// It is backed by the dedicated ``ActivityViewModel`` (not the profile-summary view model), so it
/// emits its own screen event.
struct ActivityView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.trackingApi) var trackingApi
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: ActivityViewModel

    @State private var zoomableImageInfo: ZoomableImageInfo?
    /// Guards the screen event to a single emission once the mode is resolved (the resolution happens
    /// asynchronously in clientUserId mode).
    @State private var didEmitScreenDisplayed = false
    /// The selected tab in connected-user mode (0 = Notifications, 1 = Posts, 2 = Comments — see
    /// ``ActivityTab/viewIndex``). Ignored in other-user mode, whose tabs are owned by
    /// `OtherUserPostsContainerView`.
    @State private var selectedTab: Int
    /// Guards the landing-tab application to a single shot, so a late mode resolution never overrides
    /// a tab the user already picked.
    @State private var didApplyInitialTab = false

    private let mainFlowPath: MainFlowPath
    private let canClose: Bool
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         source: ActivitySource, canClose: Bool = false,
         navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: ActivityViewModel(
            octopus: octopus, translationStore: translationStore, source: source))
        self.mainFlowPath = mainFlowPath
        self.canClose = canClose
        self.navBarLeadingAction = navBarLeadingAction
        // The floating-button source knows its landing tab synchronously — seed it at init so the
        // first frame already shows the right tab. The other sources start on a placeholder until
        // connected-user mode resolves; their real landing tab (unseen-notifications rule on a
        // self-tap) is published by the view model as `connectedUserInitialTab` and applied
        // one-shot below.
        let initialTabIndex: Int = if case let .connectedUser(initialTab) = source {
            initialTab.viewIndex
        } else {
            0
        }
        _selectedTab = State(initialValue: initialTabIndex)
    }

    var body: some View {
        Group {
            if viewModel.isConnectedUser {
                ConnectedUserActivityContentView(
                    selectedTab: $selectedTab,
                    notifCenterViewModel: viewModel.notifCenterViewModel,
                    postFeedViewModel: viewModel.postFeedViewModel,
                    commentsViewModel: viewModel.commentsViewModel,
                    canCreatePost: viewModel.canCreatePost,
                    pollsEnabled: viewModel.pollsEnabled,
                    zoomableImageInfo: $zoomableImageInfo,
                    mainFlowPath: mainFlowPath,
                    refresh: viewModel.refresh)
            } else {
                OtherUserPostsContainerView(
                    isLoaded: viewModel.postFeedViewModel != nil || viewModel.lookupFailed,
                    loadFailure: viewModel.loadFailure,
                    retryFirstLoad: viewModel.retryFirstLoad,
                    refresh: viewModel.refresh,
                    showsCommentsTab: viewModel.showsCommentsTab,
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
                                        commentId: $0, displayGoToParentButton: false, reply: $1,
                                        replyToScrollTo: nil))
                                },
                                // No-op like `ProfileSummaryView`: every post here belongs to the same
                                // member, so tapping their avatar must not re-push this same screen.
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
                            // Lookup failed: no feed to show. The empty screen (scroll + powered-by)
                            // plus the error toast/alert surfaced by the view model is the state.
                            EmptyView()
                        }
                    }
            }
        }
        // The title is passed as the centered item, not only as the nav title, so it can carry
        // `fixedSize`: a principal item keeps the width it was measured at, and this title grows from
        // "Profile" to "{nickname}'s Posts" once the member resolves — without it the longer title
        // renders truncated until the next layout pass.
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultCenteredBarItem: title
                                    .inlineNavigationBarTitleFont()
                                    .lineLimit(1)
                                    .fixedSize(),
                                navBarTitle: title)
        .toastContainer(octopus: viewModel.octopus,
                        retryFailedFetch: { Task { await viewModel.refresh() } })
        .errorAlert(viewModel.$error)
        .connectionRouter(octopus: viewModel.octopus, noConnectedReplacementAction: $viewModel.authenticationAction)
        // Other-user mode: emit once the member is resolved. Mirrors Android's
        // ScreenDisplayed.OtherUserPosts(profileId).
        .onReceive(viewModel.$resolvedProfileId) { resolvedProfileId in
            guard let resolvedProfileId, !didEmitScreenDisplayed else { return }
            didEmitScreenDisplayed = true
            trackingApi.emit(event: .screenDisplayed(.otherUserPosts(.init(profileId: resolvedProfileId))))
        }
        // Connected-user mode: emit the profile screen event once the mode resolves. iOS has no
        // dedicated "Activity" screen event, so it reuses `.profile` (the connected user's own screen,
        // like the legacy profile summary) — a documented platform adaptation of Android's
        // ScreenDisplayed.Activity.
        .onReceive(viewModel.$isConnectedUser) { isConnectedUser in
            guard isConnectedUser, !didEmitScreenDisplayed else { return }
            didEmitScreenDisplayed = true
            trackingApi.emit(event: .screenDisplayed(.profile))
        }
        // Landing tab (connected-user mode): explicit floating-button tab, or the
        // unseen-notifications rule when a self-tap resolved to the connected user. One-shot so a
        // late (async clientUserId) resolution never overrides a user-picked tab.
        .onReceive(viewModel.$connectedUserInitialTab) { initialTab in
            guard let initialTab, !didApplyInitialTab else { return }
            didApplyInitialTab = true
            selectedTab = initialTab.viewIndex
        }
    }

    /// The Comments tab content of the other-user mode — wired exactly like
    /// `ProfileSummaryView`'s, so a member's comments behave the same on both other-member screens.
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

    /// The leading nav-bar item. As the root screen (host `initialScreen` entry point), shows the
    /// host-driven leading action or a close button in modal/bridge mode; when pushed in-community
    /// (profile-tap / floating-button path) both are absent, so the default back button is used.
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

    /// The trailing nav-bar item. Connected-user mode carries the overflow menu (profile · legal ·
    /// report); other-user mode carries nothing.
    @ViewBuilder
    private var trailingBarItem: some View {
        if viewModel.isConnectedUser {
            // Both profile actions need Unified Profile ACTIVE (backend exposeClientUserId AND
            // onNavigateToProfile wired) plus a reachable host profile: a non-guest member with a
            // client id (a guest / BO / admin gets neither). Without the unified gate, "Edit my
            // profile" would fire the host's edit callback even when Unified Profile is off.
            let canOpenHostProfile = canOpenHostProfile(
                exposeClientUserId: viewModel.exposeClientUserId,
                onNavigateToProfileWired: viewModel.octopus.onNavigateToProfileCallback != nil,
                isGuest: viewModel.isGuest,
                connectedUserClientUserId: viewModel.connectedUserClientUserId)
            let externalLinks = viewModel.octopus.core.externalLinksRepository
            ActivityOverflowMenuButton(
                showViewProfile: canOpenHostProfile,
                showEditProfile: canOpenHostProfile && viewModel.octopus.onNavigateToProfileEditCallback != nil,
                onViewProfile: {
                    if let clientUserId = viewModel.connectedUserClientUserId {
                        viewModel.octopus.onNavigateToProfileCallback?(clientUserId)
                    }
                },
                // Unified Profile: open the host editor directly (no field → the full editor), rather
                // than the SDK's native edit screen.
                onEditProfile: { viewModel.octopus.onNavigateToProfileEditCallback?(nil) },
                communityGuidelinesUrl: externalLinks.communityGuidelines,
                privacyPolicyUrl: externalLinks.privacyPolicy,
                termsOfUseUrl: externalLinks.termsOfUse,
                onReportContent: { navigator.push(.reportExplanation) })
        } else {
            EmptyView()
        }
    }

    /// The nav title. Connected-user mode: a static "Activity". Other-user mode: named after the
    /// member once resolved, and the generic "Profile" until then — an empty title would leave the
    /// screen nameless while loading, and the nav bar does not always pick up a title that turns from
    /// empty to filled after the first layout (it took a scroll to appear).
    ///
    /// The member's title follows what the screen actually lists: "{nickname}'s Activity"
    /// when the Comments tab is shown, "{nickname}'s Posts" when the community keeps comments hidden
    /// and the screen is posts-only.
    private var title: Text {
        if viewModel.isConnectedUser {
            return Text("Activity.Screen.Title", bundle: .module)
        } else if let nickname = viewModel.nickname {
            return viewModel.showsCommentsTab
                ? Text("Activity.Screen.Title_name:\(nickname)", bundle: .module)
                : Text("Profile.Posts.Title_name:\(nickname)", bundle: .module)
        } else {
            return Text("Profile.Title", bundle: .module)
        }
    }
}

/// Content container of the other-user mode: a pull-to-refresh scroll of the member's posts with the
/// powered-by footer, or a loader until the feed is ready / the clientUserId lookup fails. When the
/// community exposes another member's comments the scroll is topped by the same
/// Posts/Comments tabs as `ProfileSummaryView` — with no tab bar at all when it does not, which is the
/// screen's historical posts-only look.
private struct OtherUserPostsContainerView<CommentsView: View, PostsView: View>: View {
    @Environment(\.octopusTheme) private var theme

    let isLoaded: Bool
    let loadFailure: ScreenStateFailure?
    let retryFirstLoad: () -> Void
    let refresh: @Sendable () async -> Void
    /// Whether the Comments tab should be shown (`showCommentsOnOtherProfiles`).
    let showsCommentsTab: Bool

    /// The Comments tab content.
    @ViewBuilder let commentsView: CommentsView
    @ViewBuilder let postsView: PostsView

    /// Posts(0) / Comments(1) — the same order as `ProfileSummaryView`, the other screen that shows a
    /// member's profile. Ignored while `showsCommentsTab` is false: no tab bar is rendered at all.
    @State private var selectedTab = 0
    @State private var displayStickyHeader = false
    /// Scroll offset shared by the inline tab row and the pinned pill row that replaces it.
    @State private var tabsScrollOffset: CGFloat = 0

    private let scrollViewCoordinateSpace = "otherUserActivityScrollViewCoordinateSpace"

    var body: some View {
        Group {
            if isLoaded {
                VStack(spacing: 0) {
                    Compat.ScrollView(refreshAction: refresh) {
                        VStack(spacing: 0) {
                            if showsCommentsTab {
                                tabSelector
                                    .hiddenWhilePinnedHeaderShows(displayStickyHeader)
                                theme.colors.gray300.frame(height: 1)
                                    .hiddenWhilePinnedHeaderShows(displayStickyHeader)
                            }
                            if showsCommentsTab, selectedTab == 1 {
                                commentsView
                            } else {
                                postsView
                            }
                        }
                    }
                    .coordinateSpace(name: scrollViewCoordinateSpace)
                    .postsVisibilityScrollView()
                    // Pinned tab header as an overlay (not a ZStack sibling) so it stays below the nav
                    // bar while the scroll bleeds under it — mirrors `ProfileSummaryView`.
                    .overlay(stickyTabHeader, alignment: .top)
                    PoweredByOctopusView()
                }
                // If the Comments tab disappears (config flip / feed refused) while it's selected, fall
                // back to Posts rather than leaving the selection pointing at a now-hidden tab.
                .onValueChanged(of: showsCommentsTab) { showsCommentsTab in
                    if !showsCommentsTab, selectedTab == 1 {
                        selectedTab = 0
                    }
                }
            } else if let loadFailure {
                VStack(spacing: 0) {
                    loadFailure.screenState(verticalPadding: ScreenState.profilePadding,
                                            icons: theme.assets.icons, retry: retryFirstLoad)
                    Spacer(minLength: 0)
                }
            } else {
                // Held at the design's offset rather than centered, so it lands where the first row
                // will be.
                VStack(spacing: 0) {
                    Compat.ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 130)
                    Spacer(minLength: 0)
                }
            }
        }
        .largeScreenMarginBackground()
    }

    /// Posts(0) / Comments(1) — one source of truth for both the inline selector and the pinned header,
    /// so they can never drift apart.
    private let tabs: [LocalizedStringKey] = ["Profile.Tabs.Posts", "Profile.Tabs.Comments"]

    /// The inline selector.
    private var tabSelector: some View {
        CustomSegmentedControl(tabs: tabs, selectedTab: $selectedTab, scrollOffset: $tabsScrollOffset)
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
    }

    /// Pinned tab header once the selector scrolls off: the same Instagram-style glass "pills" as the
    /// other profile screens.
    @ViewBuilder
    private var stickyTabHeader: some View {
        if showsCommentsTab, displayStickyHeader {
            ProfileStickyTabsHeader(tabs: tabs, selectedTab: $selectedTab, scrollOffset: $tabsScrollOffset)
                .transition(.opacity)
        }
    }
}

/// Connected-user mode content: segmented tabs (Notifications / Posts / Comments) over a pull-to-refresh
/// scroll, with the powered-by footer. Reuses the exact same tab-content views as the legacy profile
/// summary — `NotificationCenterView` and `PostFeedView` — but without the profile header /
/// gamification (mirrors Android's connected-user `ActivityScreen`).
private struct ConnectedUserActivityContentView: View {
    @EnvironmentObject private var navigator: Navigator<MainFlowScreen>
    @Environment(\.trackingApi) private var trackingApi
    @Environment(\.octopusTheme) private var theme

    @Binding var selectedTab: Int
    let notifCenterViewModel: NotificationCenterViewModel?
    let postFeedViewModel: PostFeedViewModel?
    /// The connected user's own comments feed, rendered on tab index 1. Always shown for the
    /// connected user's own content — never gated by `showCommentsOnOtherProfiles`.
    let commentsViewModel: ProfileCommentsListViewModel?
    let canCreatePost: Bool
    let pollsEnabled: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let mainFlowPath: MainFlowPath
    let refresh: @Sendable () async -> Void

    @State private var displayStickyHeader = false
    /// Scroll offset shared by the inline tab row and the pinned pill row that replaces it.
    @State private var tabsScrollOffset: CGFloat = 0
    private let scrollViewCoordinateSpace = "activityScrollViewCoordinateSpace"
    // Notifications first (0), Posts second (1), Comments third (2). The two landing tabs
    // (`initialTab` / `OctopusInitialScreen.activity`) map through ``ActivityTab/viewIndex``; Comments
    // is never a landing tab, so it sits last without affecting them.
    private let tabs: [LocalizedStringKey] =
        ["Profile.Tabs.Notifications", "Profile.Tabs.Posts", "Profile.Tabs.Comments"]

    var body: some View {
        VStack(spacing: 0) {
            // The tabs live inside the scroll so they scroll up with the content; once they reach the top
            // they are replaced by the floating glass "pills" overlay — the same animation as the profile
            // summary (`CurrentUserProfileContentView`).
            Compat.ScrollView(refreshAction: refresh) {
                VStack(spacing: 0) {
                    CustomSegmentedControl(tabs: tabs, selectedTab: $selectedTab,
                                           scrollOffset: $tabsScrollOffset)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onValueChanged(
                                        of: geometry.frame(in: .named(scrollViewCoordinateSpace))) { frame in
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
                    tabContent
                }
            }
            .coordinateSpace(name: scrollViewCoordinateSpace)
            .postsVisibilityScrollView()
            .overlay(stickyTabHeader, alignment: .top)
            PoweredByOctopusView()
        }
        .largeScreenMarginBackground()
    }

    @ViewBuilder
    private var stickyTabHeader: some View {
        if displayStickyHeader {
            // Instagram-style glass "pills" floating over the blurred content — matches the profile
            // summary's scrolled-tabs animation.
            ProfileStickyTabsHeader(tabs: tabs, selectedTab: $selectedTab, scrollOffset: $tabsScrollOffset)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            if let notifCenterViewModel {
                NotificationCenterView(viewModel: notifCenterViewModel)
            }
        } else if selectedTab == 2 {
            if let commentsViewModel {
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
                            commentId: $0, displayGoToParentButton: false, reply: $1,
                            replyToScrollTo: $2))
                    })
            }
        } else {
            if let postFeedViewModel {
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
                            commentId: $0, displayGoToParentButton: false, reply: $1,
                            replyToScrollTo: nil))
                    },
                    displayProfile: { _, _ in },
                    openGroup: { navigator.push(.groupDetail(groupId: $0)) },
                    displayContentModeration: {
                        mainFlowPath.reportTarget = .content(contentId: $0)
                    }) {
                        // One CTA now, not the previous post/poll pair (Screen states spec).
                        if canCreatePost {
                            ScreenState(
                                image: theme.assets.icons.screenStates.emptyContent,
                                title: .localizationKey("Profile.Posts.EmptyState.Title.Self"),
                                action: .init(title: "Profile.Posts.EmptyState.CTA.Self") {
                                    navigator.push(.createPost(withPoll: false, defaultTopicId: nil))
                                },
                                verticalPadding: ScreenState.profilePadding)
                        } else {
                            ScreenState(
                                image: theme.assets.icons.screenStates.emptyContent,
                                title: .localizationKey("Profile.Posts.EmptyState.Other"),
                                verticalPadding: ScreenState.profilePadding)
                        }
                    }
            }
        }
    }
}
