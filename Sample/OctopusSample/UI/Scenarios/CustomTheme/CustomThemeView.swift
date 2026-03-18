//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to customize the theme.
struct CustomThemeView: View {
    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()

    enum IconFamily: CaseIterable {
        case notCustomized
        case customized
        case numeric
        case tint
        case dualTint
        case horizontalRatio
        case verticalRatio
    }

    let showFullScreen: (@escaping () -> any View) -> Void

    @State private var titleCentered: Bool = false
    @State private var titleAsLogo: Bool = true
    @State private var navBarWithColor: Bool = false
    @State private var iconFamily: IconFamily = .notCustomized

    /// Create a custom theme
    var appTheme: OctopusTheme {
        OctopusTheme(
            colors: .init(
                primarySet: OctopusTheme.Colors.ColorSet(
                    main: .Scenarios.CustomTheme.Colors.primary,
                    lowContrast: .Scenarios.CustomTheme.Colors.primaryLow,
                    highContrast: .Scenarios.CustomTheme.Colors.primaryHigh)),
            fonts: .init(
                title1: Font.custom("Courier New", size: 26),
                title2: Font.custom("Courier New", size: 20),
                body1: Font.custom("Courier New", size: 17),
                body2: Font.custom("Courier New", size: 14),
                caption1: Font.custom("Courier New", size: 12),
                caption2: Font.custom("Courier New", size: 10),
                navBarItem: Font.custom("Courier New", size: 17)
            ),
            assets: .init(
                logo: UIImage(resource: .Scenarios.CustomTheme.Assets.appLogo),
                icons: iconFamily.icons))
    }



    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    Toggle(isOn: $titleCentered) {
                        Text("Center the title")
                    }
                    Toggle(isOn: $titleAsLogo) {
                        Text("Use logo on Octopus Home Screen nav bar")
                    }
                    Toggle(isOn: $navBarWithColor) {
                        Text("Use primary color on Octopus Home Screen nav bar")
                    }
                    Spacer().frame(height: 10)
                    Text("Icons customization:")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(IconFamily.allCases.indices, id: \.self) { index in
                        let iconFamily = IconFamily.allCases[index]
                        Button(action: { self.iconFamily = iconFamily }) {
                            HStack {
                                VStack(spacing: 4) {
                                    Text(iconFamily.name)
                                        .bold()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(iconFamily.comment)
                                        .font(.callout)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .multilineTextAlignment(.leading)

                                Text("\(self.iconFamily == iconFamily ? "✅" : "✔️")")
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        Color.gray.opacity(0.5).frame(height: 1)
                    }
                }
                .padding()
            }
            Button("Open Octopus Home Screen as full screen modal") {
                // Display the SDK full screen but outside the navigation view (see Architecture.md for more info)
                showFullScreen {
                    OctopusUIView(
                        octopus: viewModel.octopus,
                        // customize the leading nav bar item of the main screen.
                        // Either pass `.logo` to display the logo you provided in the theme, or `.text` to display
                        // a text you provide.
                        mainFeedNavBarTitle: .init(
                            content: titleAsLogo ? .logo : .text(.init(text: "Bake It")),
                            placement: titleCentered ? .center : .leading),
                        // pass true to use the primary color you provided in the theme on the nav bar of the main
                        // screen. Otherwise it will be the default nav bar color.
                        mainFeedColoredNavBar: navBarWithColor)
                    /// Pass the custom theme
                    .environment(\.octopusTheme, appTheme)
                }
            }
            .padding()
        }
    }
}

extension CustomThemeView.IconFamily {
    var name: String {
        switch self {
        case .notCustomized: "Default icons"
        case .customized: "Customized icons"
        case .numeric: "Customized numeric icons"
        case .tint: "Test icons: fully tinted"
        case .dualTint: "Test icons: dually tinted"
        case .horizontalRatio: "Test icons: horizontal ratio"
        case .verticalRatio: "Test icons: vertical ratio"
        }
    }

    var comment: String {
        switch self {
        case .notCustomized: "Use the default icons, provided by the SDK"
        case .customized: "Use sample icons, of a different style"
        case .numeric: "Use sample icons, each icon has a different number"
        case .tint: "All icons are a tinted circle"
        case .dualTint: "All icons are a tinted circle with two colors"
        case .horizontalRatio: "All icons are a circle in a non-squared rectangle"
        case .verticalRatio: "All icons are a circle in a non-squared rectangle"
        }
    }

    var icons: OctopusTheme.Assets.Icons {
        switch self {
        case .notCustomized: return .init()
        case .customized:
            typealias IconSet = UIImage.Scenarios.CustomTheme.Assets.Icons.NormalSet
            return .init(
                groups: .init(
                    openList: IconSet.groupsOpenList,
                    selected: IconSet.groupSelected
                ),
                content: .init(
                    post: .init(
                        creation: .init(
                            open: IconSet.contentPostCreationOpen,
                            topicSelection: IconSet.contentPostCreationTopicSelection,
                            addPicture: IconSet.contentPostCreationAddPicture,
                            deletePicture: IconSet.contentPostCreationDeletePicture,
                            addPoll: IconSet.contentPostCreationAddPoll,
                            addPollOption: IconSet.contentPostCreationAddPollOption,
                            deletePoll: IconSet.contentPostCreationDeletePoll,
                            deletePollOption: IconSet.contentPostCreationDeletePollOption
                        ),
                        emptyFeedInGroups: IconSet.contentPostEmptyFeedInGroups,
                        emptyFeedInCurrentUserProfile: IconSet.contentPostEmptyFeedInCurrentUserProfile,
                        emptyFeedInOtherUserProfile: IconSet.contentPostEmptyFeedInOtherUserProfile,
                        notAvailable: IconSet.contentPostNotAvailable,
                        commentCount: IconSet.contentPostCommentCount,
                        viewCount: IconSet.contentPostViewCount,
                        moreReactions: IconSet.contentPostMoreReactions
                    ),
                    comment: .init(
                        creation: .init(
                            open: IconSet.contentCommentCreationOpen,
                            create: IconSet.contentCommentCreationCreate,
                            addPicture: IconSet.contentCommentCreationAddPicture,
                            deletePicture: IconSet.contentCommentCreationDeletePicture
                        ),
                        emptyFeed: IconSet.contentCommentEmptyFeed,
                        notAvailable: IconSet.contentCommentNotAvailable,
                        seeReply: IconSet.contentCommentSeeReply,
                        likeNotSelected: IconSet.contentCommentLikeNotSelected
                    ),
                    reply: .init(
                        creation: .init(
                            open: IconSet.contentReplyCreationOpen,
                            create: IconSet.contentReplyCreationCreate,
                            addPicture: IconSet.contentReplyCreationAddPicture,
                            deletePicture: IconSet.contentReplyCreationDeletePicture
                        ),
                        likeNotSelected: IconSet.contentReplyLikeNotSelected
                    ),
                    video: .init(
                        muted: IconSet.contentVideoMuted,
                        notMuted: IconSet.contentVideoNotMuted,
                        pause: IconSet.contentVideoPause,
                        play: IconSet.contentVideoPlay,
                        replay: IconSet.contentVideoReplay
                    ),
                    poll: .init(
                        selectedOption: IconSet.contentPollSelectedOption
                    ),
                    delete: IconSet.contentDelete,
                    report: IconSet.contentReport
                ),
                profile: .init(
                    addPicture: IconSet.profileAddPicture,
                    editPicture: IconSet.profileEditPicture,
                    addBio: IconSet.profileAddBio,
                    emptyNotifications: IconSet.profileEmptyNotifications,
                    report: IconSet.profileReport,
                    notConnected: IconSet.profileNotConnected,
                    blockUser: IconSet.profileBlockUser
                ),
                gamification: .init(
                    badge: IconSet.gamificationBadge,
                    info: IconSet.gamificationInfo,
                    rulesHeader: IconSet.gamificationRulesHeader
                ),
                settings: .init(
                    account: IconSet.settingsAccount,
                    help: IconSet.settingsHelp,
                    info: IconSet.settingsInfo,
                    logout: IconSet.settingsLogout,
                    deleteAccountWarning: IconSet.settingsDeleteAccountWarning
                ),
                common: .init(
                    radio: .init(on: IconSet.commonRadioOn, off: IconSet.commonRadioOff),
                    checkbox: .init(on: IconSet.commonCheckboxOn, off: IconSet.commonCheckboxOff),
                    toggle: .init(on: IconSet.commonToggleOn, off: IconSet.commonToggleOff),
                    close: IconSet.commonClose,
                    moreActions: IconSet.commonMoreActions,
                    listCellNavIndicator: IconSet.commonListCellNavIndicator
                )
            )
        case .numeric:
            typealias IconSet = UIImage.Scenarios.CustomTheme.Assets.Icons.NumericSet
            return .init(
                groups: .init(
                    openList: IconSet.groupsOpenList,
                    selected: IconSet.groupSelected
                ),
                content: .init(
                    post: .init(
                        creation: .init(
                            open: IconSet.contentPostCreationOpen,
                            topicSelection: IconSet.contentPostCreationTopicSelection,
                            addPicture: IconSet.contentPostCreationAddPicture,
                            deletePicture: IconSet.contentPostCreationDeletePicture,
                            addPoll: IconSet.contentPostCreationAddPoll,
                            addPollOption: IconSet.contentPostCreationAddPollOption,
                            deletePoll: IconSet.contentPostCreationDeletePoll,
                            deletePollOption: IconSet.contentPostCreationDeletePollOption
                        ),
                        emptyFeedInGroups: IconSet.contentPostEmptyFeedInGroups,
                        emptyFeedInCurrentUserProfile: IconSet.contentPostEmptyFeedInCurrentUserProfile,
                        emptyFeedInOtherUserProfile: IconSet.contentPostEmptyFeedInOtherUserProfile,
                        notAvailable: IconSet.contentPostNotAvailable,
                        commentCount: IconSet.contentPostCommentCount,
                        viewCount: IconSet.contentPostViewCount,
                        moreReactions: IconSet.contentPostMoreReactions
                    ),
                    comment: .init(
                        creation: .init(
                            open: IconSet.contentCommentCreationOpen,
                            create: IconSet.contentCommentCreationCreate,
                            addPicture: IconSet.contentCommentCreationAddPicture,
                            deletePicture: IconSet.contentCommentCreationDeletePicture
                        ),
                        emptyFeed: IconSet.contentCommentEmptyFeed,
                        notAvailable: IconSet.contentCommentNotAvailable,
                        seeReply: IconSet.contentCommentSeeReply,
                        likeNotSelected: IconSet.contentCommentLikeNotSelected
                    ),
                    reply: .init(
                        creation: .init(
                            open: IconSet.contentReplyCreationOpen,
                            create: IconSet.contentReplyCreationCreate,
                            addPicture: IconSet.contentReplyCreationAddPicture,
                            deletePicture: IconSet.contentReplyCreationDeletePicture
                        ),
                        likeNotSelected: IconSet.contentReplyLikeNotSelected
                    ),
                    video: .init(
                        muted: IconSet.contentVideoMuted,
                        notMuted: IconSet.contentVideoNotMuted,
                        pause: IconSet.contentVideoPause,
                        play: IconSet.contentVideoPlay,
                        replay: IconSet.contentVideoReplay
                    ),
                    poll: .init(
                        selectedOption: IconSet.contentPollSelectedOption
                    ),
                    delete: IconSet.contentDelete,
                    report: IconSet.contentReport
                ),
                profile: .init(
                    addPicture: IconSet.profileAddPicture,
                    editPicture: IconSet.profileEditPicture,
                    addBio: IconSet.profileAddBio,
                    emptyNotifications: IconSet.profileEmptyNotifications,
                    report: IconSet.profileReport,
                    notConnected: IconSet.profileNotConnected,
                    blockUser: IconSet.profileBlockUser
                ),
                gamification: .init(
                    badge: IconSet.gamificationBadge,
                    info: IconSet.gamificationInfo,
                    rulesHeader: IconSet.gamificationRulesHeader
                ),
                settings: .init(
                    account: IconSet.settingsAccount,
                    help: IconSet.settingsHelp,
                    info: IconSet.settingsInfo,
                    logout: IconSet.settingsLogout,
                    deleteAccountWarning: IconSet.settingsDeleteAccountWarning
                ),
                common: .init(
                    radio: .init(on: IconSet.commonRadioOn, off: IconSet.commonRadioOff),
                    checkbox: .init(on: IconSet.commonCheckboxOn, off: IconSet.commonCheckboxOff),
                    toggle: .init(on: IconSet.commonToggleOn, off: IconSet.commonToggleOff),
                    close: IconSet.commonClose,
                    moreActions: IconSet.commonMoreActions,
                    listCellNavIndicator: IconSet.commonListCellNavIndicator
                )
            )
        case .tint, .dualTint, .horizontalRatio, .verticalRatio:
            let icon: UIImage = switch self {
            case .tint: .Scenarios.CustomTheme.Assets.Icons.Test.tint
            case .dualTint: .Scenarios.CustomTheme.Assets.Icons.Test.dualTint
            case .horizontalRatio: .Scenarios.CustomTheme.Assets.Icons.Test.horizontalRatio
            case .verticalRatio: .Scenarios.CustomTheme.Assets.Icons.Test.verticalRatio
            default: fatalError()
            }
            return .init(
                groups: .init(
                    openList: icon,
                    selected: icon
                ),
                content: .init(
                    post: .init(
                        creation: .init(
                            open: icon,
                            topicSelection: icon,
                            // addPicture: icon, defaultAddPicture will be user
                            // deletePicture: icon, defaultDeletePicture will be user
                            addPoll: icon,
                            addPollOption: icon,
                            deletePoll: icon,
                            deletePollOption: icon
                        ),
                        emptyFeedInGroups: icon,
                        emptyFeedInCurrentUserProfile: icon,
                        emptyFeedInOtherUserProfile: icon,
                        notAvailable: icon,
                        commentCount: icon,
                        viewCount: icon,
                        moreReactions: icon
                    ),
                    comment: .init(
                        creation: .init(
                            // open: icon, defaultOpenResponseCreation will be used
                            // create: icon, defaultCreateResponse will be used
                            // addPicture: icon, defaultAddPicture will be user
                            // deletePicture: icon, defaultDeletePicture will be user
                        ),
                        emptyFeed: icon,
                        notAvailable: icon,
                        // openReplyCreation: icon, defaultOpenResponseCreation will be used
                        seeReply: icon,
                        likeNotSelected: icon
                    ),
                    reply: .init(
                        creation: .init(
                            // open: icon, defaultOpenResponseCreation will be used
                            // create: icon, defaultCreateResponse will be used
                            // addPicture: icon, defaultAddPicture will be user
                            // deletePicture: icon, defaultDeletePicture will be user
                        ),
                        likeNotSelected: icon
                    ),
                    video: .init(
                        muted: icon,
                        notMuted: icon,
                        pause: icon,
                        play: icon,
                        replay: icon
                    ),
                    poll: .init(
                        selectedOption: icon
                    ),
                    delete: icon,
                    //report: icon, defaultReport will be used
                    defaultAddPicture: icon,
                    defaultDeletePicture: icon,
                    defaultCreateResponse: icon,
                    defaultOpenResponseCreation: icon
                ),
                profile: .init(
                    addPicture: icon,
                    editPicture: icon,
                    addBio: icon,
                    emptyNotifications: icon,
                    //report: icon, defaultReport will be used
                    notConnected: icon,
                    blockUser: icon
                ),
                gamification: .init(
                    badge: icon,
                    info: icon,
                    rulesHeader: icon
                ),
                settings: .init(
                    account: icon,
                    help: icon,
                    info: icon,
                    logout: icon,
                    deleteAccountWarning: icon
                ),
                common: .init(
                    radio: .init(on: icon, off: icon),
                    checkbox: .init(on: icon, off: icon),
                    toggle: .init(on: icon, off: icon),
                    close: icon,
                    moreActions: icon,
                    listCellNavIndicator: icon
                ),
                defaultReport: icon
            )
        }
    }
}
