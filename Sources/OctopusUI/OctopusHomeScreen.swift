//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import os
import Octopus
import Combine
import UserNotifications

/// UI Entry point.
///
/// The `OctopusHomeScreen` displays the horizontally scrollable list of feeds on the top and the main feed as a
/// content.
///
/// This SwiftUI view contains a NavigationView, hence it should be not embedded in another Navigation object.
public struct OctopusHomeScreen: View {
    
    /// The kind of navigation bar leading item
    public enum NavBarLeadingItemKind {
        /// A text title
        public struct TextTitle {
            /// The text to display. To have better UI results, please keep it as little as possible as it will be
            /// displayed on one line (no more than 18 chars)
            public let text: String
            
            /// Constructor
            /// - Parameter text: The text to display.
            ///                   To have better UI results, please keep it as little as possible as it will be
            ///                   displayed on one line (no more than 18 chars)
            public init(text: String) {
                self.text = text
            }
        }
        /// The nav bar leading item will be the `logo` you provided in the Theme
        case logo
        /// The nav bar leading item will be the text you provide.
        /// To have better UI results, please keep the text as little as possible as it will be
        /// displayed on one line (no more than 18 chars)
        case text(TextTitle)
    }

    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Binding var notificationResponse: UNNotificationResponse?

    private let octopus: OctopusSDK
    private let bottomSafeAreaInset: CGFloat
    private let navBarLeadingItem: NavBarLeadingItemKind
    private let navBarPrimaryColor: Bool
    private let postId: String?

    @Compat.StateObject private var mainFlowPath = MainFlowPath()

    /// Constructor of the `OctopusHomeScreen`.
    /// - Parameters:
    ///    - octopus: The Octopus SDK
    ///    - bottomSafeAreaInset: the bottom safe area inset. Default is 0. Only used on iOS 15+.
    ///    - navBarLeadingItem: the kind of info to display on the nav bar leading item of the main screen.
    ///                         It is either `.logo` to display the logo you passed in the Theme, or `.text` to display
    ///                         a text you can provide (less than 18chars is recommanded). Default is `.logo`.
    ///    - navBarPrimaryColor: whether the primary color you set in the theme should be used on the nav bar of the
    ///                          main screen. If false, default nav bar color will be used. Default is false.
    ///    - postId: the id of the post to be directly displayed. If nil, post feed with the feed selector will be
    ///              displayed. Default is nil.
    ///    - notificationResponse: a binding on the notification response if an Octopus Push Notification has been
    ///                            tapped. Default is nil. The binding is set back to nil after the notification has
    ///                            been used inside Octopus (i.e. the screen relative to the notification has been
    ///                            displayed).
    ///  
    /// You can pass an OctopusTheme as an environment to customize the colors, fonts and images used in this
    /// view:
    /// ```swift
    /// OctopusHomeScreen(octopus: octopus)
    ///     .environment(\.octopusTheme, appTheme)
    /// ```
    public init(octopus: OctopusSDK,
                bottomSafeAreaInset: CGFloat = 0,
                navBarLeadingItem: NavBarLeadingItemKind = .logo,
                navBarPrimaryColor: Bool = false,
                postId: String? = nil,
                notificationResponse: Binding<UNNotificationResponse?> = .constant(nil)) {
        self.octopus = octopus
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.navBarLeadingItem = navBarLeadingItem
        if #available(iOS 16.0, *), navBarPrimaryColor {
            self.navBarPrimaryColor = true
        } else {
            self.navBarPrimaryColor = false
        }
        self.postId = postId
        self._notificationResponse = notificationResponse
    }

    public var body: some View {
        MainFlowNavigationStack(octopus: octopus, mainFlowPath: mainFlowPath, bottomSafeAreaInset: bottomSafeAreaInset) {
            if #available(iOS 14.0, *) {
            if let postId {
                PostDetailView(octopus: octopus, mainFlowPath: mainFlowPath, postUuid: postId,
                               comment: false,
                               commentToScrollTo: nil,
                               scrollToMostRecentComment: false,
                               shouldTrackEventBridgeOpened: true)
                .navigationBarItems(
                    trailing:
                        Group {
                            if presentationMode.wrappedValue.isPresented {
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Text("Common.Close", bundle: .module)
                                        .font(theme.fonts.navBarItem)
                                }
                            }
                        }
                )
                .onAppear {
                    if presentationMode.wrappedValue.isPresented && !isPresentedModally {
                        Logger.general.warning(
                            "⚠️ You are trying to push the OctopusHomeScreen from a screen that already has a navigation bar.")
                    }
                }
                .insetableMainNavigationView(bottomSafeAreaInset: bottomSafeAreaInset)
            } else {
                RootFeedsView(octopus: octopus, mainFlowPath: mainFlowPath, navBarLeadingItem: navBarLeadingItem,
                              navBarPrimaryColor: navBarPrimaryColor)
                .onAppear {
                    if presentationMode.wrappedValue.isPresented && !isPresentedModally {
                        Logger.general.warning(
                            "⚠️ You are trying to push the OctopusHomeScreen from a screen that already has a navigation bar.")
                    }
                }
                .safeAreaInsetCompat(edge: .bottom) {
                    Spacer().frame(height: bottomSafeAreaInset)
                }
            }
            } else {
                UnsupportedOSVersionView()
                    .navigationBarItems(
                        trailing:
                            Group {
                                if presentationMode.wrappedValue.isPresented {
                                    Button(action: {
                                        presentationMode.wrappedValue.dismiss()
                                    }) {
                                        Text("Common.Close", bundle: .module)
                                            .font(theme.fonts.navBarItem)
                                    }
                                }
                            }
                    )
            }
        }
        .onAppear {
            octopus.core.trackingRepository.octopusUISessionStarted()
            displayScreenAfterNotificationTapped(notificationResponse: notificationResponse)
        }
        .onDisappear {
            octopus.core.trackingRepository.octopusUISessionEnded()
        }
        .accentColor(theme.colors.primary)
        .navigationViewStyle(.stack)
        .onValueChanged(of: notificationResponse) {
            displayScreenAfterNotificationTapped(notificationResponse: $0)
        }
    }

    private func displayScreenAfterNotificationTapped(notificationResponse: UNNotificationResponse?) {
        guard let notificationResponse else { return }
        defer { self.notificationResponse = nil }
        guard let action = octopus.core.notificationsRepository.getPushNotificationTappedAction(
            notificationResponse: notificationResponse) else { return }
        switch action {
        case let .open(contentsToOpen):
            mainFlowPath.path = contentsToOpen.map { $0.mainFlowScreen }
        }
    }
}


private extension View {
    @MainActor
    var isPresentedModally: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            return false
        }
        return window.rootViewController?.presentedViewController != nil
    }
}
