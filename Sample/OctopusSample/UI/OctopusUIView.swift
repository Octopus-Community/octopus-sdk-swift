//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusUI
import Octopus

/// Wrapper around the OctopusHomeScreen that adds the user related views modally
struct OctopusUIView: View {
    let octopus: OctopusSDK
    let bottomSafeAreaInset: CGFloat
    let mainFeedNavBarTitle: OctopusMainFeedTitle?
    let mainFeedColoredNavBar: Bool
    let initialScreen: OctopusInitialScreen
    let navigationMode: OctopusNavigationMode

    @Binding var octopusNotificationUserInfo: [AnyHashable: Any]?

    @State private var displayAppUserLogin = false
    @State private var displayEditAppUserProfile = false
    @State private var displayGroupAccessDenied = false
    @State private var groupAccessDeniedGroupId: String = ""
    @State private var displayClientProfile = false
    @State private var clientProfileClientUserId: String = ""

    @State private var isDisplayed = false

    // Internal-demo only: the SDK always follows the host app's layout direction. To preview RTL
    // (Arabic) without switching the whole device to an RTL language, simulate an RTL host by forcing
    // the layout direction on the Octopus view when an RTL override language is selected.
    @Environment(\.layoutDirection) private var inheritedLayoutDirection
    @ObservedObject private var languageManager = SampleLanguageManager.instance

    init(
        octopus: OctopusSDK,
        bottomSafeAreaInset: CGFloat = 0,
        mainFeedNavBarTitle: OctopusMainFeedTitle? = nil,
        mainFeedColoredNavBar: Bool = false,
        initialScreen: OctopusInitialScreen = .mainFeed,
        navigationMode: OctopusNavigationMode = .automatic,
        octopusNotificationUserInfo: Binding<[AnyHashable: Any]?> = .constant(nil)) {
        self.octopus = octopus
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.mainFeedNavBarTitle = mainFeedNavBarTitle
        self.mainFeedColoredNavBar = mainFeedColoredNavBar
        self.initialScreen = initialScreen
        self.navigationMode = navigationMode
        self._octopusNotificationUserInfo = octopusNotificationUserInfo
    }

    var body: some View {
        OctopusHomeScreen(
            octopus: octopus,
            bottomSafeAreaInset: bottomSafeAreaInset,
            mainFeedNavBarTitle: mainFeedNavBarTitle,
            mainFeedColoredNavBar: mainFeedColoredNavBar,
            initialScreen: initialScreen,
            navigationMode: navigationMode,
            notificationUserInfo: $octopusNotificationUserInfo
        )
        // Force RTL only when an RTL override language is picked; otherwise keep the inherited direction.
        .environment(\.layoutDirection,
                     languageManager.simulatedLayoutDirection == .rightToLeft ? .rightToLeft : inheritedLayoutDirection)
        .fullScreenCover(isPresented: $displayAppUserLogin) {
            AppLoginScreen()
        }
        .fullScreenCover(isPresented: $displayEditAppUserProfile) {
            AppEditUserScreen()
        }
        .fullScreenCover(isPresented: $displayGroupAccessDenied) {
            GroupAccessDeniedScreen(groupId: groupAccessDeniedGroupId)
        }
        .fullScreenCover(isPresented: $displayClientProfile) {
            ClientProfileScreen(clientUserId: clientProfileClientUserId)
        }
        .onReceive(ClientProfileManager.instance.$tappedClientUserId) {
            guard isDisplayed, let clientUserId = $0 else { return }
            clientProfileClientUserId = clientUserId
            displayClientProfile = true
            // Consume the tap immediately so `tappedClientUserId` behaves as a one-shot event.
            // If it stayed non-nil while ClientProfileScreen is shown, any OTHER OctopusUIView that
            // appears on top (notably the "See their Octopus posts" activity screen, which is itself
            // an OctopusUIView) would re-receive this current value the moment it subscribes — a
            // `@Published` replays its current value to every new subscriber — and re-fire this
            // handler. That competing presentation cancels the just-presented activity sheet, so the
            // button looked broken. Resetting here (rather than on dismiss) closes that window.
            ClientProfileManager.instance.tappedClientUserId = nil
        }
        .onReceive(ClientProfileManager.instance.$editProfileRequested) {
            guard isDisplayed, $0 else { return }
            // "Edit my profile" from the connected-user Activity menu → host's own edit screen.
            displayEditAppUserProfile = true
            // Consume the one-shot event immediately (mirrors tappedClientUserId above).
            ClientProfileManager.instance.editProfileRequested = false
        }
        .onReceive(GroupAccessDeniedManager.instance.$deniedGroupId) {
            guard isDisplayed, let groupId = $0 else { return }
            // Editing entitlements requires a connected user. If the host app's user is not
            // logged in yet, route through the login flow first — they can pick the
            // entitlements inline on the login screen, then connectUser will mint a JWT
            // with those claims.
            if AppUserManager.instance.appUser == nil,
               case .sso = SDKConfigManager.instance.sdkConfig?.authKind {
                displayAppUserLogin = true
                GroupAccessDeniedManager.instance.deniedGroupId = nil
                return
            }
            groupAccessDeniedGroupId = groupId
            displayGroupAccessDenied = true
        }
        .onValueChanged(of: displayGroupAccessDenied) {
            guard !$0 else { return }
            GroupAccessDeniedManager.instance.deniedGroupId = nil
        }
        .onReceive(OctopusSDKProvider.instance.$clientLoginRequired) {
            guard isDisplayed else { return }
            guard $0 else { return }
            displayAppUserLogin = true
        }
        .onValueChanged(of: displayAppUserLogin) {
            guard !$0 else { return }
            OctopusSDKProvider.instance.clientLoginRequired = false
        }
        .onReceive(OctopusSDKProvider.instance.$clientModifyUserAsked) {
            guard isDisplayed else { return }
            guard $0 else { return }
            displayEditAppUserProfile = true
        }
        .onValueChanged(of: displayEditAppUserProfile) {
            guard !$0 else { return }
            OctopusSDKProvider.instance.clientModifyUserAsked = false
        }
        .onAppear {
            isDisplayed = true
        }
        .onDisappear {
            isDisplayed = false
        }
    }
}
