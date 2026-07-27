//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct MainFlowNavigationStack<RootView: View>: View {
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore
    @EnvironmentObject private var gamificationRulesViewManager: GamificationRulesViewManager
    @Environment(\.octopusTheme) private var theme

    let octopus: OctopusSDK
    let bottomSafeAreaInset: CGFloat
    let navigationMode: OctopusNavigationMode
    @Compat.StateObject private var mainFlowPath: MainFlowPath
    @ViewBuilder let rootView: RootView

    @State private var bottomInset: CGFloat

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, bottomSafeAreaInset: CGFloat = 0,
         navigationMode: OctopusNavigationMode = .automatic,
         @ViewBuilder _ rootView: () -> RootView) {
        self.octopus = octopus
        _mainFlowPath = Compat.StateObject(wrappedValue: mainFlowPath)
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.navigationMode = navigationMode
        self.rootView = rootView()
        self._bottomInset = .init(initialValue: bottomSafeAreaInset)
    }

    /// Maps the public navigation mode onto the `NavigationBackport` policy.
    /// `.automatic` keeps the legacy `NavigationView` (see the `TODO Djavan` note below), while
    /// `.navigationStack` opts into a real `NavigationStack` on iOS 16+ (legacy fallback below).
    private var navigationStackPolicy: UseNavigationStackPolicy {
        switch navigationMode {
        case .automatic: return .never
        case .navigationStack: return .whenAvailable
        }
    }

    var body: some View {
        NBNavigationStack(path: $mainFlowPath.path) {
            rootView
                // The custom createPost slide-up is driven by a `UINavigationControllerDelegate` proxy.
                // It works with the legacy `NavigationView` (`.automatic`) but must NOT be installed with a
                // real `NavigationStack` (`.navigationStack`, iOS 16+): SwiftUI's `NavigationStack` needs to
                // own the nav-controller delegate to animate its pushes, so hijacking it there silently
                // drops the push animation for every screen (post, profile, …). In that mode we let SwiftUI
                // animate natively; createPost falls back to the standard horizontal push.
                .modify {
                    if navigationMode == .automatic {
                        $0.installOctopusNavTransitionProxy { [mainFlowPath] operation, _, _ in
                            guard operation == .push else { return false }
                            if case .createPost = mainFlowPath.path.last { return true }
                            return false
                        }
                    } else {
                        $0
                    }
                }
                .hideBackButtonTitle()
                .nbNavigationDestination(for: MainFlowScreen.self) { screen in
                    Group {
                        switch screen {
                        case .currentUserProfile:
                            CurrentUserProfileSummaryView(
                                octopus: octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
                                gamificationRulesViewManager: gamificationRulesViewManager)
                        case let .publicProfile(profileId):
                            ProfileSummaryView(
                                octopus: octopus, mainFlowPath: mainFlowPath,
                                translationStore: translationStore, profileId: profileId)
                        case let .activity(source):
                            ActivityView(
                                octopus: octopus, mainFlowPath: mainFlowPath,
                                translationStore: translationStore, source: source)
                        case let .createPost(withPoll, defaultTopicId):
                            // In `.automatic` the editor slides up like a modal, so show a close (X)
                            // instead of a back chevron. In `.navigationStack` it's a standard horizontal
                            // push (see the proxy gating above), where a back chevron is more natural.
                            CreatePostView(octopus: octopus, withPoll: withPoll, defaultTopicId: defaultTopicId,
                                           canClose: navigationMode == .automatic)
                        case let .groupList(context):
                            GroupListView(octopus: octopus, context: context)
                        case let .groupDetail(groupId):
                            GroupDetailView(octopus: octopus, groupId: groupId, mainFlowPath: mainFlowPath,
                                            translationStore: translationStore)
                        case let .postDetail(postId, comment, commentToScrollTo, scrollToMostRecentComment, origin, hasFeaturedComment):
                            PostDetailView(
                                octopus: octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
                                postUuid: postId,
                                comment: comment,
                                commentToScrollTo: commentToScrollTo,
                                scrollToMostRecentComment: scrollToMostRecentComment,
                                origin: origin,
                                hasFeaturedComment: hasFeaturedComment)
                        case let .commentDetail(commentId, displayGoToParentButton, reply, replyToScrollTo):
                            CommentDetailView(octopus: octopus, mainFlowPath: mainFlowPath,
                                              translationStore: translationStore,
                                              commentUuid: commentId,
                                              displayGoToParentButton: displayGoToParentButton,
                                              reply: reply, replyToScrollTo: replyToScrollTo)
                        case let .editProfile(bioFocused, pictureFocused):
                            EditProfileView(octopus: octopus, bioFocused: bioFocused, photoPickerFocused: pictureFocused)
                        case .settingsAccount:
                            SettingProfileView(octopus: octopus)
                        case .reportExplanation:
                            ReportExplanationView(octopus: octopus)
                        case .deleteAccount:
                            DeleteAccountView(octopus: octopus, mainFlowPath: mainFlowPath)
                        }
                    }
                    .insetableMainNavigationView(bottomSafeAreaInset: bottomSafeAreaInset)
                    .hideBackButtonTitle()
                }

        }
        .sheet(item: $mainFlowPath.reportTarget) { target in
            ReportScreen(octopus: octopus, target: target)
                .modify {
                    if #available(iOS 16.0, *) {
                        $0.presentationDragIndicator(.visible)
                    } else { $0 }
                }
                .modify {
                    // do not use presentationBackground on iOS 17 because it breaks the layout when the view is presented
                    if #available(iOS 18.0, *) {
                        $0.presentationBackground(theme.colors.background)
                    } else { $0 }
                }
        }
        // TODO Djavan remove this as it forces to use navigationView instead of navigationStack. It has been set
        // because of a bug impacting the CreatePostView that was re-created when put in background.
        // The policy can now be overridden via `OctopusHomeScreen`'s `navigationMode` (`.navigationStack`)
        // for hosts that present the SDK in a modal, where the legacy NavigationView drops pushes.
        .nbUseNavigationStack(navigationStackPolicy)
    }
}
