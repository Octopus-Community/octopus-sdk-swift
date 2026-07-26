//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

/// Whether the connected-user Activity screen's overflow menu can open the host's profile screen
/// (Unified Profile, OCT-1374). **Both** the Unified Profile activation gate (see
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

/// The "activity" screen (Unified Profile, OCT-1374). Polymorphic like Android's single
/// `ActivityScreen`, driven by the resolved ``ActivityMode``:
/// - **connected-user mode**: the connected user's own activity — a static "Activity" title, a
///   top-right overflow menu (profile · legal · report), and two tabs (Notifications, Posts). No
///   profile header, no gamification (that is exposed to the host via the read-only community-data
///   API instead). Opened by the home floating button (`ActivitySource.connectedUser`), or when a
///   profileId / clientUserId entry point resolves to the connected user's own id.
/// - **other-user mode**: another member's posts under a "{nickname}'s Posts" title, with no header,
///   no tabs and no overflow menu — the in-community profile-tap path (`ActivitySource.profileId`) or
///   the `OctopusInitialScreen.activity` host entry point (`ActivitySource.clientUserId`).
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
    /// The selected tab in connected-user mode (0 = Notifications, 1 = Posts). Ignored in other-user
    /// mode, which has no tabs.
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
            initialTab == .notifications ? 0 : 1
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
                    canCreatePost: viewModel.canCreatePost,
                    pollsEnabled: viewModel.pollsEnabled,
                    zoomableImageInfo: $zoomableImageInfo,
                    mainFlowPath: mainFlowPath,
                    refresh: viewModel.refresh)
            } else {
                OtherUserPostsContainerView(
                    isLoaded: viewModel.postFeedViewModel != nil || viewModel.lookupFailed,
                    refresh: viewModel.refresh) {
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
                                    OtherUserEmptyPostView()
                                }
                        } else {
                            // Lookup failed: no feed to show. The empty screen (scroll + powered-by)
                            // plus the error toast/alert surfaced by the view model is the state.
                            EmptyView()
                        }
                    }
            }
        }
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarTitle: title)
        .toastContainer(octopus: viewModel.octopus)
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
            selectedTab = initialTab == .notifications ? 0 : 1
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

    /// The nav title. Connected-user mode: a static "Activity". Other-user mode: "{nickname}'s Posts",
    /// empty while the profile is still loading so we never show an empty-name "'s Posts".
    private var title: Text {
        if viewModel.isConnectedUser {
            return Text("Activity.Screen.Title", bundle: .module)
        } else if let nickname = viewModel.nickname {
            return Text("Profile.Posts.Title_name:\(nickname)", bundle: .module)
        } else {
            return Text(verbatim: "")
        }
    }
}

/// Posts-only container of the other-user mode: a pull-to-refresh scroll of the member's posts with
/// the powered-by footer, or a loader until the feed is ready / the clientUserId lookup fails.
private struct OtherUserPostsContainerView<PostsView: View>: View {
    let isLoaded: Bool
    let refresh: @Sendable () async -> Void

    @ViewBuilder let postsView: PostsView

    var body: some View {
        Group {
            if isLoaded {
                VStack(spacing: 0) {
                    Compat.ScrollView(refreshAction: refresh) {
                        postsView
                    }
                    .postsVisibilityScrollView()
                    PoweredByOctopusView()
                }
            } else {
                Compat.ProgressView()
            }
        }
        .largeScreenMarginBackground()
    }
}

/// Connected-user mode content: fixed segmented tabs (Notifications / Posts) over a pull-to-refresh
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
    let canCreatePost: Bool
    let pollsEnabled: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let mainFlowPath: MainFlowPath
    let refresh: @Sendable () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Notifications first, Posts second (0 / 1) — matching Android's Activity tab order and
            // `currentUserActivityDestination`.
            CustomSegmentedControl(tabs: ["Profile.Tabs.Notifications", "Profile.Tabs.Posts"],
                                   tabCount: 2, selectedTab: $selectedTab)
            theme.colors.gray300.frame(height: 1)
            Compat.ScrollView(refreshAction: refresh) {
                if selectedTab == 0 {
                    if let notifCenterViewModel {
                        NotificationCenterView(viewModel: notifCenterViewModel)
                    }
                } else {
                    if let postFeedViewModel {
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
                                    commentId: $0, displayGoToParentButton: false, reply: $1,
                                    replyToScrollTo: nil))
                            },
                            displayProfile: { _, _ in },
                            openGroup: { navigator.push(.groupDetail(groupId: $0)) },
                            displayContentModeration: {
                                mainFlowPath.reportTarget = .content(contentId: $0)
                            }) {
                                if canCreatePost {
                                    CreatePostEmptyPostView(
                                        createPost: { navigator.push(.createPost(withPoll: $0, defaultTopicId: nil)) },
                                        pollsEnabled: pollsEnabled)
                                } else {
                                    DefaultEmptyPostsView()
                                }
                            }
                    }
                }
            }
            .postsVisibilityScrollView()
            PoweredByOctopusView()
        }
        .largeScreenMarginBackground()
    }
}
