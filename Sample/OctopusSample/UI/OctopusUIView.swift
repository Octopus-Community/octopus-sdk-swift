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

    @Binding var octopusNotificationUserInfo: [AnyHashable: Any]?

    @State private var displayAppUserLogin = false
    @State private var displayEditAppUserProfile = false

    @State private var isDisplayed = false

    init(
        octopus: OctopusSDK,
        bottomSafeAreaInset: CGFloat = 0,
        mainFeedNavBarTitle: OctopusMainFeedTitle? = nil,
        mainFeedColoredNavBar: Bool = false,
        initialScreen: OctopusInitialScreen = .mainFeed,
        octopusNotificationUserInfo: Binding<[AnyHashable: Any]?> = .constant(nil)) {
        self.octopus = octopus
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.mainFeedNavBarTitle = mainFeedNavBarTitle
        self.mainFeedColoredNavBar = mainFeedColoredNavBar
        self.initialScreen = initialScreen
        self._octopusNotificationUserInfo = octopusNotificationUserInfo
    }

    var body: some View {
        OctopusHomeScreen(
            octopus: octopus,
            bottomSafeAreaInset: bottomSafeAreaInset,
            mainFeedNavBarTitle: mainFeedNavBarTitle,
            mainFeedColoredNavBar: mainFeedColoredNavBar,
            initialScreen: initialScreen,
            notificationUserInfo: $octopusNotificationUserInfo
        )
        .fullScreenCover(isPresented: $displayAppUserLogin) {
            AppLoginScreen()
        }
        .fullScreenCover(isPresented: $displayEditAppUserProfile) {
            AppEditUserScreen()
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
