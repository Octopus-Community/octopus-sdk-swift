//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct CurrentUserProfileSummaryView: View {
    @EnvironmentObject private var gamificationRulesViewManager: GamificationRulesViewManager
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.trackingApi) var trackingApi
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CurrentUserProfileSummaryViewModel

    @State private var displayDeleteUserAlert = false

    @State private var displayOpenEditProfileInApp = false
    @State private var openEditProfileInApp: (() -> Void)?

    @State private var showGamificationRules = false

    @State private var zoomableImageInfo: ZoomableImageInfo?

    @State private var isDisplayed = false

    private let mainFlowPath: MainFlowPath
    private let canClose: Bool
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         gamificationRulesViewManager: GamificationRulesViewManager, canClose: Bool = false,
         navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: CurrentUserProfileSummaryViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
            gamificationRulesViewManager: gamificationRulesViewManager))
        self.mainFlowPath = mainFlowPath
        self.canClose = canClose
        self.navBarLeadingAction = navBarLeadingAction
    }

    var body: some View {
        ContentView(
            profile: viewModel.profile,
            gamificationConfig: viewModel.gamificationConfig,
            displayAccountAge: viewModel.displayAccountAge,
            editability: viewModel.editability,
            zoomableImageInfo: $zoomableImageInfo,
            hasInitialNotSeenNotifications: viewModel.hasInitialNotSeenNotifications,
            refresh: viewModel.refresh,
            openEdition: {
                openEdition(field: nil)
            }, openEditionWithBioFocused: {
                openEdition(field: .bio)
            }, openEditionWithPhotoPicker: {
                openEdition(field: .picture)
            },
            openGamificationRules: { showGamificationRules = true },
            postsView: {
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
                            if viewModel.canCreatePost {
                                CreatePostEmptyPostView(
                                    createPost: { navigator.push(.createPost(withPoll: $0, defaultTopicId: nil)) },
                                    pollsEnabled: viewModel.pollsEnabled)
                            } else {
                                DefaultEmptyPostsView()
                            }
                        }
                } else {
                    EmptyView()
                }
            }, notificationsView: {
                NotificationCenterView(viewModel: viewModel.notifCenterViewModel)
            })
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarTitle: Text("Profile.Title", bundle: .module))
        .toastContainer(octopus: viewModel.octopus)
        .gamificationRulesSheet(
            isPresented: $showGamificationRules,
            gamificationConfig: viewModel.gamificationConfig,
            gamificationRulesViewManager: gamificationRulesViewManager)
        .errorAlert(viewModel.$error, onDismiss: { viewModel.error = nil })
        .compatAlert(
            "Profile.Edit.ClientApp.Alert.Title",
            isPresented: $displayOpenEditProfileInApp,
            presenting: openEditProfileInApp,
            actions: { openEditProfileInApp in
                Button(action: openEditProfileInApp) {
                    Text("Common.Ok", bundle: .module)
                }
                Button(action: {}) {
                    Text("Common.Cancel", bundle: .module)
                }
            },
            message: { _ in })
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            navigator.popToRoot()
        }
        // Logout confirmation (overflow menu row, Octopus-owned profile only) — mirrors the former
        // `SettingsListView` alert: acknowledge, then pop to the community root.
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Settings.LogOut.Done.Title", bundle: .module),
                    isPresented: $viewModel.logoutDone, actions: {
                        Button(action: { navigator.popToRoot() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $viewModel.logoutDone) {
                    Alert(title: Text("Settings.LogOut.Done.Title", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        navigator.popToRoot()
                    }))
                }
            }
        }
        .onReceive(viewModel.$forceDisplayGamificationRules) {
            guard $0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if isDisplayed {
                    showGamificationRules = true
                }
            }
        }
        .onAppear {
            isDisplayed = true
        }
        .emitScreenDisplayed(.profile, trackingApi: trackingApi)
        .onDisappear {
            isDisplayed = false
        }
    }

    func openEdition(field: CurrentUserProfileSummaryViewModel.CoreProfileField?) {
        enum Action {
            case openOctopusEdition(CurrentUserProfileSummaryViewModel.CoreProfileField?)
            case openAlertToAppEdition(() -> Void)
            case openAppEdition(() -> Void)
        }
        let action: Action
        switch viewModel.editConfig {
        case let .editInApp(editProfileCallback):
            if let field {
                action = .openAlertToAppEdition({ editProfileCallback(field) })
            } else {
                action = .openAppEdition({ editProfileCallback(nil) })
            }
        case let .mixed(appManagedFields, editProfileCallback):
            if let field {
                if appManagedFields.contains(field) {
                    action = .openAlertToAppEdition({ editProfileCallback(field) })
                } else {
                    action = .openOctopusEdition(field)
                }
            } else {
                action = .openOctopusEdition(nil)
            }
        case .editInOctopus:
            action = .openOctopusEdition(field)
        }

        switch action {
        case let .openOctopusEdition(field):
            navigator.push(.editProfile(bioFocused: field == .bio, pictureFocused: field == .picture))
        case let .openAlertToAppEdition(openAppEdition):
            openEditProfileInApp = openAppEdition
            displayOpenEditProfileInApp = true
        case let .openAppEdition(openAppEdition):
            openAppEdition()
        }
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

    /// The "…" overflow menu. It used to push a separate "Community settings" screen
    /// (`SettingsListView`); it now opens the same menu as the Activity screen (PO feedback,
    /// 2026-07-17) — legal links + report, plus the account-settings and logout rows for an
    /// Octopus-owned profile. The Unified Profile "View/Edit my profile" rows stay hidden here:
    /// this legacy screen only shows when Unified Profile is inactive, and profile edition is
    /// already available on the screen itself.
    @ViewBuilder
    private var trailingBarItem: some View {
        let externalLinks = viewModel.octopus.core.externalLinksRepository
        ActivityOverflowMenuButton(
            showViewProfile: false,
            showEditProfile: false,
            onViewProfile: {},
            onEditProfile: {},
            communityGuidelinesUrl: externalLinks.communityGuidelines,
            privacyPolicyUrl: externalLinks.privacyPolicy,
            termsOfUseUrl: externalLinks.termsOfUse,
            onReportContent: { navigator.push(.reportExplanation) },
            showAccountSettings: viewModel.octopusOwnedProfile,
            onAccountSettings: { navigator.push(.settingsAccount) },
            showLogout: viewModel.octopusOwnedProfile,
            onLogout: viewModel.logout)
    }
}

private struct ContentView<PostsView: View, NotificationsView: View>: View {
    let profile: DisplayableCurrentUserProfile?
    let gamificationConfig: GamificationConfig?
    let displayAccountAge: Bool
    let editability: ProfileFieldsEditability
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let hasInitialNotSeenNotifications: Bool
    let refresh: @Sendable () async -> Void
    let openEdition: () -> Void
    let openEditionWithBioFocused: () -> Void
    let openEditionWithPhotoPicker: () -> Void
    let openGamificationRules: () -> Void

    @ViewBuilder let postsView: PostsView
    @ViewBuilder let notificationsView: NotificationsView

    var body: some View {
        if let profile {
            VStack(spacing: 0) {
                // On iOS 26 the navigation bar uses its default translucent (glass) behavior (OCT-1532).
                CurrentUserProfileContentView(profile: profile,
                                   gamificationConfig: gamificationConfig,
                                   displayAccountAge: displayAccountAge,
                                   editability: editability,
                                   zoomableImageInfo: $zoomableImageInfo,
                                   hasInitialNotSeenNotifications: hasInitialNotSeenNotifications,
                                   refresh: refresh, openEdition: openEdition,
                                   openEditionWithBioFocused: openEditionWithBioFocused,
                                   openEditionWithPhotoPicker: openEditionWithPhotoPicker,
                                   openGamificationRules: openGamificationRules,
                                   postsView: { postsView },
                                   notificationsView: { notificationsView })
                PoweredByOctopusView()
            }
            .largeScreenMarginBackground()
        } else {
            Compat.ProgressView()
                .frame(width: 60)
        }
    }
}
