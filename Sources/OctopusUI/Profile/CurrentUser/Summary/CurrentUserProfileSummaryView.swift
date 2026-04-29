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

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         gamificationRulesViewManager: GamificationRulesViewManager) {
        _viewModel = Compat.StateObject(wrappedValue: CurrentUserProfileSummaryViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
            gamificationRulesViewManager: gamificationRulesViewManager))
    }

    var body: some View {
        ContentView(
            profile: viewModel.profile,
            gamificationConfig: viewModel.gamificationConfig,
            displayAccountAge: viewModel.displayAccountAge,
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
                        displayProfile: { _ in },
                        displayContentModeration: {
                            navigator.push(.reportContent(contentId: $0))
                        }) {
                            CreatePostEmptyPostView(createPost: { navigator.push(.createPost(withPoll: $0, defaultTopic: nil)) })
                        }
                } else {
                    EmptyView()
                }
            }, notificationsView: {
                NotificationCenterView(viewModel: viewModel.notifCenterViewModel)
            })
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
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
    private var trailingBarItem: some View {
        Button(action: { navigator.push(.settingsList) }) {
            if #available(iOS 26.0, *) {
                Label(title: { Text("Accessibility.Common.More", bundle: .module) },
                      icon: { Image(uiImage: theme.assets.icons.common.moreActions) })
            } else {
                Image(uiImage: theme.assets.icons.common.moreActions)
                    .font(theme.fonts.navBarItem)
                    .padding(.vertical)
                    .padding(.leading)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .modify {
            if #unavailable(iOS 26.0) {
                $0.buttonStyle(.plain)
            } else { $0 }
        }
        .accessibilityLabelInBundle("Settings.Community.Title")
    }
}

private struct ContentView<PostsView: View, NotificationsView: View>: View {
    let profile: DisplayableCurrentUserProfile?
    let gamificationConfig: GamificationConfig?
    let displayAccountAge: Bool
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
#if compiler(>=6.2)
                // Disable nav bar opacity on iOS 26 to have the same behavior as before.
                // TODO: See with product team if we need to keep it.
                if #available(iOS 26.0, *) {
                    Color.white.opacity(0.0001)
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                }
#endif
                CurrentUserProfileContentView(profile: profile,
                                   gamificationConfig: gamificationConfig,
                                   displayAccountAge: displayAccountAge,
                                   zoomableImageInfo: $zoomableImageInfo,
                                   hasInitialNotSeenNotifications: hasInitialNotSeenNotifications,
                                   refresh: refresh, openEdition: openEdition,
                                   openEditionWithBioFocused: openEditionWithBioFocused,
                                   openEditionWithPhotoPicker: openEditionWithPhotoPicker,
                                   openGamificationRules: openGamificationRules,
                                   postsView: { postsView },
                                   notificationsView: { notificationsView })
                .padding(.top, 8)
                PoweredByOctopusView()
            }
        } else {
            Compat.ProgressView()
                .frame(width: 60)
        }
    }
}
