//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusUI
import Octopus
import UIKit
import SwiftUI

@Suite(.disabled("Disabled because we only need that they compile"))
@MainActor
class APITests {
    private let connectionMode = ConnectionMode.sso(.init(loginRequired: { }))

    @Test func testHomeScreen() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY", connectionMode: connectionMode)
        _ = OctopusHomeScreen(octopus: octopusSdk)
        _ = OctopusHomeScreen(octopus: octopusSdk, bottomSafeAreaInset: 5)
        _ = OctopusHomeScreen(octopus: octopusSdk, mainFeedNavBarTitle: nil)
        _ = OctopusHomeScreen(octopus: octopusSdk, mainFeedColoredNavBar: true)
        _ = OctopusHomeScreen(octopus: octopusSdk, initialScreen: .mainFeed)
        _ = OctopusHomeScreen(octopus: octopusSdk, initialScreen: .post(.init(postId: "POST_ID")))
        _ = OctopusHomeScreen(octopus: octopusSdk, initialScreen: .group(.init(groupId: "GROUP_ID")))
        _ = OctopusHomeScreen(octopus: octopusSdk,
                              initialScreen: .activity(.init(clientUserId: "CLIENT_USER_ID")))
        _ = OctopusHomeScreen(octopus: octopusSdk,
                              initialScreen: .activity(.init(profileId: "PROFILE_ID")))
        _ = OctopusHomeScreen(octopus: octopusSdk, navigationMode: .automatic)
        _ = OctopusHomeScreen(octopus: octopusSdk, navigationMode: .navigationStack)
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarLeadingAction: .close(onTap: {}))
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarLeadingAction: .back(onTap: {}))
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarLeadingAction: nil)
        _ = OctopusHomeScreen(octopus: octopusSdk, initialScreen: .post(.init(postId: "P")),
                              navBarLeadingAction: .back(onTap: {}))
        _ = OctopusHomeScreen(octopus: octopusSdk, navigationMode: .navigationStack,
                              navBarLeadingAction: .close(onTap: {}))
        _ = OctopusHomeScreen(octopus: octopusSdk, notificationUserInfo: .constant(nil))
        _ = OctopusHomeScreen(octopus: octopusSdk, notificationUserInfo: .constant(["k": "v"]))
    }

    @Test func testOctopusThemeApi() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY", connectionMode: connectionMode)
        // check that init with default params is available
        var theme = OctopusTheme()
        // check that it is customizable
        theme = OctopusTheme(
            colors: .init(primarySet: .init(main: .red, lowContrast: .blue, highContrast: .yellow),
                          onPrimary: .white,
                          link: .green),
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
                logo: UIImage(),
                icons: .init()
            )
        )

        // check that it can be passed as environment
        _ = OctopusHomeScreen(octopus: octopusSdk)
            .environment(\.octopusTheme, theme)
    }

    @Test func testPostIconsApi() async throws {
        // check that Post icons can be constructed with likeNotSelected
        _ = OctopusTheme.Assets.Icons.Content.Post(likeNotSelected: UIImage())
        // check that defaultLikeNotSelected cascades to post
        _ = OctopusTheme.Assets.Icons.Content(
            defaultLikeNotSelected: UIImage()
        )
    }

    @Test func testCommonIconsApi() async throws {
        // Default construction
        _ = OctopusTheme.Assets.Icons.Common()
        // Partial override: the Unified Profile activity button icon (shown in place of the
        // connected user's avatar on the home floating button when Unified Profile is active)
        _ = OctopusTheme.Assets.Icons.Common(activityButton: UIImage())
        // Partial override: the button that clears a text field
        _ = OctopusTheme.Assets.Icons.Common(clearText: UIImage())
        // Every parameter at once, in declaration order
        _ = OctopusTheme.Assets.Icons.Common(
            radio: .init(on: UIImage(), off: UIImage()),
            checkbox: .init(on: UIImage(), off: UIImage()),
            toggle: .init(on: UIImage(), off: UIImage()),
            close: UIImage(),
            moreActions: UIImage(),
            activityButton: UIImage(),
            listCellNavIndicator: UIImage(),
            clearText: UIImage())
        // Wired into Icons
        _ = OctopusTheme.Assets.Icons(common: .init(activityButton: UIImage()))
        _ = OctopusTheme.Assets.Icons(common: .init(clearText: UIImage()))
    }

    @Test func testMainFeedTitle() async throws {
        _ = OctopusMainFeedTitle(content: .logo, placement: .center)
        _ = OctopusMainFeedTitle(content: .text(.init(text: "")), placement: .leading)
    }

    @Test func testReactionIconsApi() async throws {
        // Default construction
        _ = OctopusTheme.Assets.Icons.Content.Reaction()
        // Partial override
        _ = OctopusTheme.Assets.Icons.Content.Reaction(heart: UIImage())
        // Full override
        _ = OctopusTheme.Assets.Icons.Content.Reaction(
            heart: UIImage(), joy: UIImage(), mouthOpen: UIImage(),
            clap: UIImage(), cry: UIImage(), rage: UIImage()
        )
        // Wired into Content
        _ = OctopusTheme.Assets.Icons.Content(reaction: .init())
        _ = OctopusTheme.Assets.Icons.Content(
            reaction: .init(heart: UIImage())
        )
    }

    @Test func testSettingsIconsApi() async throws {
        _ = OctopusTheme.Assets.Icons.Settings()
        _ = OctopusTheme.Assets.Icons.Settings(help: UIImage())
        let settings = OctopusTheme.Assets.Icons.Settings(help: UIImage(), info: UIImage())
        let _: UIImage = settings.help
        let _: UIImage = settings.info
        _ = OctopusTheme.Assets.Icons(settings: settings)
    }

    @Test func testEmptyStateIconsApi() async throws {
        _ = OctopusTheme.Assets.Icons.Content.Post()
        _ = OctopusTheme.Assets.Icons.Content.Post(
            creation: .init(), notAvailable: UIImage(), commentCount: UIImage(), viewCount: UIImage(),
            moreReactions: UIImage(), likeNotSelected: UIImage(), moderated: UIImage())
        _ = OctopusTheme.Assets.Icons.Content.Comment()
        _ = OctopusTheme.Assets.Icons.Content.Comment(
            creation: .init(), notAvailable: UIImage(), seeReply: UIImage(), likeNotSelected: UIImage())
        _ = OctopusTheme.Assets.Icons.Profile()
        _ = OctopusTheme.Assets.Icons.Profile(
            addPicture: UIImage(), editPicture: UIImage(), addBio: UIImage(), report: UIImage(),
            notConnected: UIImage(), blockUser: UIImage())
        // the empty lists are customized through the screen states
        _ = OctopusTheme.Assets.Icons(
            screenStates: .init(emptyContent: UIImage(), emptyNotifications: UIImage()))
    }

    @Test func testThemeWithCustomBackgroundCompiles() {
        _ = OctopusTheme(colors: OctopusTheme.Colors(
            primarySet: .init(main: .blue, lowContrast: .blue, highContrast: .blue),
            onPrimary: .white,
            link: .blue,
            background: .green))
    }

    @Test func testOctopusHomeScreenWithCreatePostInitialScreen() throws {
        let sdk = try OctopusSDK(apiKey: "API_KEY", connectionMode: connectionMode)
        let prefill = try OctopusPrefilledPost(
            text: "hello world long enough",
            cta: try OctopusPrefilledPost.CTA(
                url: URL(string: "https://example.com")!, label: "Open"))
        _ = OctopusHomeScreen(
            octopus: sdk,
            initialScreen: .createPost(.init(prefilledPost: prefill))
        )
        _ = OctopusHomeScreen(
            octopus: sdk,
            initialScreen: .createPost(.init())
        )
    }

    @Test func testProfileScreen() throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY", connectionMode: connectionMode)
        _ = OctopusProfileScreen(octopus: octopusSdk)
        _ = OctopusProfileScreen(octopus: octopusSdk, clientUserId: "CLIENT_USER_ID")
        _ = OctopusProfileScreen(octopus: octopusSdk, navigationMode: .automatic)
        _ = OctopusProfileScreen(octopus: octopusSdk, navigationMode: .navigationStack)
        _ = OctopusProfileScreen(octopus: octopusSdk, navBarLeadingAction: .close(onTap: {}))
        _ = OctopusProfileScreen(octopus: octopusSdk, navBarLeadingAction: .back(onTap: {}))
        _ = OctopusProfileScreen(
            octopus: octopusSdk, clientUserId: "CLIENT_USER_ID",
            navigationMode: .navigationStack, navBarLeadingAction: .close(onTap: {}))
    }

}

/// Deprecated APIs (tests are still here to ensure old APIs can still be called)
extension APITests {
    @Test func testOldHomeScreen() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY", connectionMode: connectionMode)
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarLeadingItem: .logo)
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarLeadingItem: .text(.init(text: "")))
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarPrimaryColor: true)
        _ = OctopusHomeScreen(octopus: octopusSdk, mainFeedNavBarTitle: nil, postId: "POST_ID")
        _ = OctopusHomeScreen(octopus: octopusSdk, mainFeedNavBarTitle: nil, notificationResponse: .constant(nil))
    }

    @Test func testOldSettingsIconsApi() async throws {
        let settings = OctopusTheme.Assets.Icons.Settings(
            account: UIImage(), help: UIImage(), info: UIImage(), logout: UIImage(),
            deleteAccountWarning: UIImage())
        let _: UIImage = settings.account
        let _: UIImage = settings.logout
        let _: UIImage = settings.deleteAccountWarning
    }

    @Test func testOldEmptyStateIconsApi() async throws {
        let post = OctopusTheme.Assets.Icons.Content.Post(
            creation: .init(), emptyFeedInGroups: UIImage(), emptyFeedInCurrentUserProfile: UIImage(),
            emptyFeedInOtherUserProfile: UIImage(), notAvailable: UIImage(), commentCount: UIImage(),
            viewCount: UIImage(), moreReactions: UIImage(), likeNotSelected: UIImage(), moderated: UIImage())
        let _: UIImage = post.emptyFeedInGroups
        let _: UIImage = post.emptyFeedInCurrentUserProfile
        let _: UIImage = post.emptyFeedInOtherUserProfile
        let comment = OctopusTheme.Assets.Icons.Content.Comment(
            creation: .init(), emptyFeed: UIImage(), notAvailable: UIImage(), seeReply: UIImage(),
            likeNotSelected: UIImage())
        let _: UIImage = comment.emptyFeed
        let profile = OctopusTheme.Assets.Icons.Profile(
            addPicture: UIImage(), editPicture: UIImage(), addBio: UIImage(), emptyNotifications: UIImage(),
            report: UIImage(), notConnected: UIImage(), blockUser: UIImage())
        let _: UIImage = profile.emptyNotifications
    }
}
