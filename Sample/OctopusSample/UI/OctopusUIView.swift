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
    let navBarLeadingItem: OctopusHomeScreen.NavBarLeadingItemKind
    let navBarPrimaryColor: Bool
    let postId: String?

    @Binding var octopusNotification: UNNotificationResponse?

    @State private var displayAppUserLogin = false
    @State private var displayEditAppUserProfile = false

    @State private var isDisplayed = false

    init(
        octopus: OctopusSDK,
        bottomSafeAreaInset: CGFloat = 0,
        navBarLeadingItem: OctopusHomeScreen.NavBarLeadingItemKind = .logo,
        navBarPrimaryColor: Bool = false,
        postId: String? = nil,
        octopusNotification: Binding<UNNotificationResponse?> = .constant(nil)) {
        self.octopus = octopus
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.navBarLeadingItem = navBarLeadingItem
        self.navBarPrimaryColor = navBarPrimaryColor
        self.postId = postId
        self._octopusNotification = octopusNotification
    }

    var body: some View {
        OctopusHomeScreen(
            octopus: octopus,
            bottomSafeAreaInset: bottomSafeAreaInset,
            navBarLeadingItem: navBarLeadingItem,
            navBarPrimaryColor: navBarPrimaryColor,
            postId: postId,
            notificationResponse: $octopusNotification
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
