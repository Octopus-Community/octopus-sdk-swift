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
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CurrentUserProfileSummaryViewModel

    @State private var displayDeleteUserAlert = false

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

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
                            CreatePostEmptyPostView(createPost: { navigator.push(.createPost(withPoll: $0)) })
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
        .toastContainer(octopus: viewModel.octopus)
        .sheet(isPresented: $showGamificationRules) {
            if let gamificationConfig = viewModel.gamificationConfig {
                GamificationRulesScreen(gamificationConfig: gamificationConfig,
                                      gamificationRulesViewManager:gamificationRulesViewManager
                ).sizedSheet()
            } else {
                EmptyView()
            }
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
        EmptyView()
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        Button(action: { navigator.push(.settingsList) }) {
            if #available(iOS 26.0, *) {
                Label(L10n("Accessibility.Common.More"), systemImage: "ellipsis")
            } else {
                Image(systemName: "ellipsis")
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
                ProfileContentView(profile: profile,
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

private struct ProfileContentView<PostsView: View, NotificationsView: View>: View {
    @Environment(\.octopusTheme) private var theme
    let profile: DisplayableCurrentUserProfile
    let gamificationConfig: GamificationConfig?
    let displayAccountAge: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let refresh: @Sendable () async -> Void
    let openEdition: () -> Void
    let openEditionWithBioFocused: () -> Void
    let openEditionWithPhotoPicker: () -> Void
    let openGamificationRules: () -> Void
    @ViewBuilder let postsView: PostsView
    @ViewBuilder let notificationsView: NotificationsView

    @State private var selectedTab: Int
    @State private var displayStickyHeader = false

    @State private var displayFullBio = false

    private let scrollViewCoordinateSpace = "scrollViewCoordinateSpace"

    init(profile: DisplayableCurrentUserProfile,
         gamificationConfig: GamificationConfig?,
         displayAccountAge: Bool,
         zoomableImageInfo: Binding<ZoomableImageInfo?>,
         hasInitialNotSeenNotifications: Bool,
         refresh: @escaping @Sendable () async -> Void,
         openEdition: @escaping () -> Void,
         openEditionWithBioFocused: @escaping () -> Void,
         openEditionWithPhotoPicker: @escaping () -> Void,
         openGamificationRules: @escaping () -> Void,
         @ViewBuilder postsView: @escaping () -> PostsView,
         @ViewBuilder notificationsView: @escaping () -> NotificationsView) {
        self.profile = profile
        self.gamificationConfig = gamificationConfig
        self.displayAccountAge = displayAccountAge
        self._zoomableImageInfo = zoomableImageInfo
        self.refresh = refresh
        self.openEdition = openEdition
        self.openEditionWithBioFocused = openEditionWithBioFocused
        self.openEditionWithPhotoPicker = openEditionWithPhotoPicker
        self.openGamificationRules = openGamificationRules
        self.postsView = postsView()
        self.notificationsView = notificationsView()
        self._selectedTab = State(wrappedValue: hasInitialNotSeenNotifications ? 1 : 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Compat.ScrollView(refreshAction: refresh) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 16) {
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
                                .accessibilityHintInBundle("Accessibility.Profile.Picture.Edit")
                            } else {
                                ZoomableAuthorAvatarView(avatar: avatar, zoomableImageInfo: $zoomableImageInfo)
                                    .frame(width: 71, height: 71)
                            }

                            VStack(alignment: .leading, spacing: 0) {
                                Text(profile.nickname)
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
                                        .padding(.top, 6)
                                } else if let gamificationConfig {
                                    Button(action: openGamificationRules) {
                                        VStack(alignment: .leading, spacing: 0) {
                                            AdaptiveAccessibleStack2Contents(
                                                hStackSpacing: 0,
                                                vStackAlignment: .leading,
                                                vStackSpacing: 4,
                                                horizontalContent: {
                                                    GamificationLevelBadge(level: profile.gamificationLevel, size: .big)
                                                    Spacer(minLength: 8)
                                                    if let gamificationScore = profile.gamificationScore,
                                                       let gamificationLevel = profile.gamificationLevel {
                                                        GamificationScoreToTargetView(
                                                            gamificationLevel: gamificationLevel,
                                                            gamificationScore: gamificationScore,
                                                            gamificationConfig: gamificationConfig)
                                                    }
                                                }, verticalContent: {
                                                    GamificationLevelBadge(level: profile.gamificationLevel, size: .big)
                                                    if let gamificationScore = profile.gamificationScore,
                                                       let gamificationLevel = profile.gamificationLevel {
                                                        GamificationScoreToTargetView(
                                                            gamificationLevel: gamificationLevel,
                                                            gamificationScore: gamificationScore,
                                                            gamificationConfig: gamificationConfig)
                                                    }
                                                })

                                            if let gamificationScore = profile.gamificationScore,
                                               let level = profile.gamificationLevel,
                                               let nextLevelAt = level.nextLevelAt {
                                                Spacer().frame(height: 8)
                                                GamificationProgressionBar(
                                                    currentScore: gamificationScore,
                                                    startScore: level.startAt,
                                                    targetScore: nextLevelAt)
                                            }
                                        }
                                        .padding(.top, 6)
                                        .padding(.bottom, 4)
                                    }.buttonStyle(.plain)
                                } else {
                                    Spacer().frame(height: 8)
                                }
                            }
                        }

                        Spacer().frame(height: 14)

                        ProfileCounterView(totalMessages: profile.totalMessages,
                                           accountCreationDate: displayAccountAge ? profile.accountCreationDate : nil)

                        if let bio = profile.bio {
                            Group {
                                if bio.isEllipsized {
                                    Text(verbatim: "\(bio.getText(ellipsized: !displayFullBio))\(!displayFullBio ? "... " : " ")")
                                    +
                                    Text(displayFullBio ? L10n("Common.ReadLess") : L10n("Common.ReadMore"))
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

                            Spacer().frame(height: 12)

                            Button(action: openEdition) {
                                HStack(spacing: 4) {
                                    Text("Profile.Edit.Button", bundle: .module)
                                        .font(theme.fonts.body2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(theme.colors.gray900)
                            }
                            .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true,
                                                           externalVerticalPadding: 5))
                        } else {
                            AdaptiveAccessibleStack(
                                hStackSpacing: 8,
                                vStackAlignment: .leading,
                                vStackSpacing: 4) {
                                    Button(action: openEditionWithBioFocused) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(theme.fonts.body2.weight(.light))
                                            Text("Profile.Detail.EmptyBio.Button", bundle: .module)
                                                .font(theme.fonts.body2)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(theme.colors.gray900)
                                    }
                                    .buttonStyle(OctopusButtonStyle(.mid, style: .outline, hasLeadingIcon: true,
                                                                    externalVerticalPadding: 5))

                                    Button(action: openEdition) {
                                        HStack(spacing: 4) {
                                            Text("Profile.Edit.Button", bundle: .module)
                                                .font(theme.fonts.body2)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(theme.colors.gray900)
                                    }
                                    .buttonStyle(OctopusButtonStyle(.mid, style: .outline,
                                                                    externalVerticalPadding: 5))
                                }
                        }
                    }
                    .padding(.horizontal, 16)

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

private struct GamificationScoreToTargetView: View {
    @Environment(\.octopusTheme) private var theme

    let gamificationLevel: GamificationLevel
    let gamificationScore: Int
    let gamificationConfig: GamificationConfig


    var body: some View {
        HStack(spacing: 0) {
            if let nextLevelAt = gamificationLevel.nextLevelAt {
                Text(verbatim: "\(gamificationScore) / \(nextLevelAt) \(gamificationConfig.pointsName)")
            } else {
                Text(verbatim: "\(gamificationScore) \(gamificationConfig.pointsName)")
            }

            Image(systemName: "info.circle")
                .font(theme.fonts.caption1)
                .scaleEffect(0.9)
                .padding(.horizontal, 2)
        }
        .font(theme.fonts.caption1.weight(.semibold))
        .foregroundColor(theme.colors.primary)
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 4)
            .fill(theme.colors.primaryLowContrast)
        )
    }
}
