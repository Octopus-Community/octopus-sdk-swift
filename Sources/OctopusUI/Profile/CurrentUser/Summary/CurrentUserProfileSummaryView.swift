//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct CurrentUserProfileSummaryView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CurrentUserProfileSummaryViewModel

    @State private var openCreatePost = false
    @State private var displayDeleteUserAlert = false

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var displayOpenEditProfileInApp = false
    @State private var openEditProfileInApp: (() -> Void)?

    @State private var zoomableImageInfo: ZoomableImageInfo?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath) {
        _viewModel = Compat.StateObject(wrappedValue: CurrentUserProfileSummaryViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath))
    }

    var body: some View {
        ContentView(
            profile: viewModel.profile,
            zoomableImageInfo: $zoomableImageInfo,
            hasInitialNotSeenNotifications: viewModel.hasInitialNotSeenNotifications,
            refresh: viewModel.refresh,
            openEdition: {
                openEdition(field: nil)
            }, openEditionWithBioFocused: {
                openEdition(field: .bio)
            }, openEditionWithPhotoPicker: {
                openEdition(field: .picture)
            }, postsView: {
                if let postFeedViewModel = viewModel.postFeedViewModel {
                    PostFeedView(
                        viewModel: postFeedViewModel,
                        zoomableImageInfo: $zoomableImageInfo,
                        displayPostDetail: {
                            navigator.push(.postDetail(postId: $0, comment: $1, commentToScrollTo: nil,
                                                       scrollToMostRecentComment: $2))
                        },
                        displayProfile: { _ in },
                        displayContentModeration: {
                            navigator.push(.reportContent(contentId: $0))
                        }) {
                            CreatePostEmptyPostView(createPost: { openCreatePost = true })
                        }
                } else {
                    EmptyView()
                }
            }, notificationsView: {
                NotificationCenterView(viewModel: viewModel.notifCenterViewModel)
            })
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem)
        .fullScreenCover(isPresented: $openCreatePost) {
            CreatePostView(octopus: viewModel.octopus)
        }
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
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
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            navigator.popToRoot()
        }
        .onValueChanged(of: displayError) {
            guard !$0 else { return }
            viewModel.error = nil
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
        EmptyView()
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        Button(action: { navigator.push(.settingsList) }) {
            Image(systemName: "ellipsis")
                .modify {
                    if #available(iOS 26.0, *) {
                        $0
                    } else {
                        $0.padding(.vertical)
                        .padding(.leading)
                    }
                }
                .font(theme.fonts.navBarItem)
        }
        .buttonStyle(.plain)
    }
}

private struct ContentView<PostsView: View, NotificationsView: View>: View {
    let profile: CurrentUserProfile?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let hasInitialNotSeenNotifications: Bool
    let refresh: @Sendable () async -> Void
    let openEdition: () -> Void
    let openEditionWithBioFocused: () -> Void
    let openEditionWithPhotoPicker: () -> Void

    @ViewBuilder let postsView: PostsView
    @ViewBuilder let notificationsView: NotificationsView

    var body: some View {
        if let profile {
            VStack(spacing: 0) {
                // Disable nav bar opacity on iOS 26 to have the same behavior as before.
                // TODO: See with product team if we need to keep it.
                if #available(iOS 26.0, *) {
                    Color.white.opacity(0.0001)
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                }
                ProfileContentView(profile: profile,
                                   zoomableImageInfo: $zoomableImageInfo,
                                   hasInitialNotSeenNotifications: hasInitialNotSeenNotifications,
                                   refresh: refresh, openEdition: openEdition,
                                   openEditionWithBioFocused: openEditionWithBioFocused,
                                   openEditionWithPhotoPicker: openEditionWithPhotoPicker,
                                   postsView: { postsView },
                                   notificationsView: { notificationsView })
                PoweredByOctopusView()
            }
        } else {
            Compat.ProgressView()
                .frame(width: 60)
        }
    }
}

private struct ProfileContentView<PostsView: View, NotificationsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: CurrentUserProfile
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void
    let openEdition: () -> Void
    let openEditionWithBioFocused: () -> Void
    let openEditionWithPhotoPicker: () -> Void
    @ViewBuilder let postsView: PostsView
    @ViewBuilder let notificationsView: NotificationsView

    @State private var selectedTab: Int
    @State private var displayStickyHeader = false

    private let scrollViewCoordinateSpace = "scrollViewCoordinateSpace"

    init(profile: CurrentUserProfile,
         zoomableImageInfo: Binding<ZoomableImageInfo?>,
         hasInitialNotSeenNotifications: Bool,
         refresh: @escaping @Sendable () async -> Void,
         openEdition: @escaping () -> Void,
         openEditionWithBioFocused: @escaping () -> Void,
         openEditionWithPhotoPicker: @escaping () -> Void,
         @ViewBuilder postsView: @escaping () -> PostsView,
         @ViewBuilder notificationsView: @escaping () -> NotificationsView) {
        self.profile = profile
        self._zoomableImageInfo = zoomableImageInfo
        self.refresh = refresh
        self.openEdition = openEdition
        self.openEditionWithBioFocused = openEditionWithBioFocused
        self.openEditionWithPhotoPicker = openEditionWithPhotoPicker
        self.postsView = postsView()
        self.notificationsView = notificationsView()
        self._selectedTab = State(wrappedValue: hasInitialNotSeenNotifications ? 1 : 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Compat.ScrollView(refreshAction: refresh) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            if case .defaultImage = avatar {
                                Button(action: openEditionWithPhotoPicker) {
                                    AuthorAvatarView(avatar: avatar)
                                        .frame(width: 71, height: 71)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .foregroundColor(theme.colors.onPrimary)
                                                .padding(4)
                                                .background(theme.colors.primary)
                                                .clipShape(Circle())
                                                .frame(width: 20, height: 20)
                                                .offset(x: 26, y: 26)
                                        )
                                }
                                .buttonStyle(.plain)
                            } else {
                                ZoomableAuthorAvatarView(avatar: avatar, zoomableImageInfo: $zoomableImageInfo)
                                    .frame(width: 71, height: 71)
                            }
                            Spacer()
                            Button(action: openEdition) {
                                Text("Profile.Edit.Button", bundle: .module)
                            }
                            .buttonStyle(OctopusButtonStyle(.mid(.outline)))
                        }
                        Spacer().frame(height: 20)
                        Text(profile.nickname)
                            .font(theme.fonts.title1)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.gray900)
                            .modify {
                                if #available(iOS 15.0, *) {
                                    $0.textSelection(.enabled)
                                } else { $0 }
                            }
                        Spacer().frame(height: 10)
                        if let bio = profile.bio?.nilIfEmpty {
                            Text(bio.cleanedBio)
                                .font(theme.fonts.body2)
                                .foregroundColor(theme.colors.gray900)
                                .modify {
                                    if #available(iOS 15.0, *) {
                                        $0.textSelection(.enabled)
                                    } else { $0 }
                                }
                        } else {
                            Button(action: openEditionWithBioFocused) {
                                HStack(spacing: 2) {
//                                    Image(systemName: "plus")
                                    Text("Profile.Detail.EmptyBio.Button", bundle: .module)
                                }
                            }
                            .buttonStyle(OctopusButtonStyle(.mid(.outline), hasLeadingIcon: false))
                        }
                    }
                    .padding(.horizontal, 20)
                    CustomSegmentedControl(tabs: ["Profile.Tabs.Posts", "Profile.Tabs.Notifications"],
                                           tabCount: 2, selectedTab: $selectedTab)
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
                    if selectedTab == 0 {
                        postsView
                    } else {
                        notificationsView
                    }

                }
            }
            .coordinateSpace(name: scrollViewCoordinateSpace)

            if displayStickyHeader {
                CustomSegmentedControl(tabs: ["Profile.Tabs.Posts", "Profile.Tabs.Notifications"],
                                       tabCount: 2, selectedTab: $selectedTab)
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    private var avatar: Author.Avatar {
        if let pictureUrl = profile.pictureUrl {
            return .image(url: pictureUrl, name: profile.nickname)
        } else {
            return .defaultImage(name: profile.nickname)
        }
    }
}
