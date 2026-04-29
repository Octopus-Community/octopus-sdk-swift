//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore
import UIKit

struct CurrentUserProfileContentView<PostsView: View, NotificationsView: View>: View {
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
                                            Image(uiImage: theme.assets.icons.profile.addPicture)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
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

                            Spacer().frame(height: 12)

                            Button(action: openEdition) {
                                HStack(spacing: 4) {
                                    Text("Profile.Edit.Button", bundle: .module)
                                        .font(theme.fonts.body2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(theme.colors.gray900)
                            }
                            .buttonStyle(OctopusButtonStyle(.mid, style: .outline, externalVerticalPadding: 5))
                        } else {
                            AdaptiveAccessibleStack(
                                hStackSpacing: 8,
                                vStackAlignment: .leading,
                                vStackSpacing: 4) {
                                    Button(action: openEditionWithBioFocused) {
                                        HStack(spacing: 4) {
                                            IconImage(theme.assets.icons.profile.addBio)
                                            Text("Profile.Detail.EmptyBio.Button", bundle: .module)
                                                .fontWeight(.medium)
                                        }
                                        .font(theme.fonts.body2)
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
            .postsVisibilityScrollView()

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
