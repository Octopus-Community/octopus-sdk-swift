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

    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Binding var notificationUserInfo: [AnyHashable: Any]?

    private let octopus: OctopusSDK
    private let bottomSafeAreaInset: CGFloat
    private let mainFeedNavBarTitle: OctopusMainFeedTitle?
    private let mainFeedColoredNavBar: Bool
    private let initialScreen: OctopusInitialScreen

    @Compat.StateObject private var viewModel: OctopusHomeScreenViewModel
    @Compat.StateObject private var translationStore: ContentTranslationPreferenceStore
    @State private var trackingApi: DefaultTrackingApi
    @Compat.StateObject private var gamificationRulesViewManager: GamificationRulesViewManager
    @Compat.StateObject private var displayConfigManager: DisplayConfigManager
    @Compat.StateObject private var videoManager: VideoManager
    @State private var urlOpener: URLOpener
    @Compat.StateObject private var languageManager: LanguageManager

    /// Constructor of the `OctopusHomeScreen`.
    /// - Parameters:
    ///    - octopus: The Octopus SDK
    ///    - bottomSafeAreaInset: the bottom safe area inset. Default is 0. Only used on iOS 15+.
    ///    - mainFeedNavBarTitle: the title displayed in the navigation on the main feed screen (the feed that is
    ///                           displayed when you open the Octopus UI without specifying a postId).
    ///                           The content is either `.logo` to display the logo you passed in the Theme,
    ///                           or `.text` to display a text you can provide (less than 18chars is recommanded).
    ///                           You can also specify if the content should be placed on the left or centered.
    ///                           Default is nil, meaning that default title ("Community") will be displayed at the
    ///                           leading place.
    ///    - mainFeedColoredNavBar: whether the primary color you set in the theme should be used on the nav bar of the
    ///                             main feed screen (the feed that is displayed when you open the Octopus UI without
    ///                             specifying a postId).
    ///                             If false, default nav bar color will be used. Default is false.
    ///    - initialScreen: the initial screen to display. Default is `.mainFeed` which shows the feed with the feed
    ///                     selector. Use `.post` or `.group` to open a specific post or group in bridge mode.
    ///    - notificationUserInfo: a binding on the `userInfo` dictionary of a push notification (i.e. the
    ///                            `request.content.userInfo` of a `UNNotification`, or the raw payload received
    ///                            from cross-platform push plugins like Firebase Messaging).
    ///                            If an Octopus push notification's `userInfo` is supplied, the SDK navigates to the
    ///                            matching screen. Default is nil. The binding is set back to nil after the
    ///                            notification has been consumed (i.e. the screen relative to the notification has
    ///                            been displayed).
    ///
    /// You can pass an OctopusTheme as an environment to customize the colors, fonts and images used in this
    /// view:
    /// ```swift
    /// OctopusHomeScreen(octopus: octopus)
    ///     .environment(\.octopusTheme, appTheme)
    /// ```
    public init(octopus: OctopusSDK,
                bottomSafeAreaInset: CGFloat = 0,
                mainFeedNavBarTitle: OctopusMainFeedTitle? = nil,
                mainFeedColoredNavBar: Bool = false,
                initialScreen: OctopusInitialScreen = .mainFeed,
                notificationUserInfo: Binding<[AnyHashable: Any]?> = .constant(nil)) {
        _viewModel = Compat.StateObject(wrappedValue: OctopusHomeScreenViewModel(octopus: octopus))
        _translationStore = Compat.StateObject(wrappedValue: ContentTranslationPreferenceStore(
            repository: octopus.core.contentTranslationPreferenceRepository))
        _trackingApi = State(wrappedValue: DefaultTrackingApi(octopus: octopus))
        _gamificationRulesViewManager = Compat.StateObject(wrappedValue: GamificationRulesViewManager(octopus: octopus))
        _displayConfigManager = Compat.StateObject(wrappedValue: DisplayConfigManager(octopus: octopus))
        _videoManager = Compat.StateObject(wrappedValue: VideoManager(octopus: octopus))
        _urlOpener = State(wrappedValue: URLOpener(octopus: octopus))
        _languageManager = Compat.StateObject(wrappedValue: LanguageManager(octopus: octopus))
        self.octopus = octopus
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.mainFeedNavBarTitle = mainFeedNavBarTitle
        if #available(iOS 16.0, *), mainFeedColoredNavBar {
            self.mainFeedColoredNavBar = true
        } else {
            self.mainFeedColoredNavBar = false
        }
        self.initialScreen = initialScreen
        self._notificationUserInfo = notificationUserInfo
    }

    public var body: some View {
        MainFlowNavigationStack(octopus: octopus, mainFlowPath: viewModel.mainFlowPath, bottomSafeAreaInset: bottomSafeAreaInset) {
            if #available(iOS 14.0, *) {
                Group {
                    if viewModel.displayCommunityAccessDenied {
                        CommunityAccessDeniedView(octopus: octopus, canClose: presentationMode.wrappedValue.isPresented)
                    } else {
                        Group {
                            switch initialScreen {
                            case .mainFeed:
                                MainRootFeedView(
                                    octopus: octopus,
                                    mainFlowPath: viewModel.mainFlowPath,
                                    navBarTitle: mainFeedNavBarTitle,
                                    coloredNavBar: mainFeedColoredNavBar)
                            case let .post(info):
                                PostDetailView(
                                    octopus: octopus, mainFlowPath: viewModel.mainFlowPath,
                                    translationStore: translationStore,
                                    postUuid: info.postId,
                                    comment: false,
                                    commentToScrollTo: nil,
                                    scrollToMostRecentComment: false,
                                    origin: .clientApp,
                                    hasFeaturedComment: false,
                                    canClose: presentationMode.wrappedValue.isPresented)
                            case let .group(info):
                                GroupDetailView(
                                    octopus: octopus, groupId: info.groupId,
                                    mainFlowPath: viewModel.mainFlowPath,
                                    translationStore: translationStore,
                                    canClose: presentationMode.wrappedValue.isPresented,
                                    origin: .clientApp)
                            }
                        }
                    }
                }
                .insetableMainNavigationView(bottomSafeAreaInset: bottomSafeAreaInset)
                .onAppear {
                    if presentationMode.wrappedValue.isPresented && !isPresentedModally {
                        Logger.general.warning(
                            "⚠️ You are trying to push the OctopusHomeScreen from a screen that already has a navigation bar.")
                    }
                }
            } else {
                UnsupportedOSVersionView()
                    .navigationBarItems(trailing: closeModalButton)
            }
        }
        .modify {
            // do not use presentationBackground on iOS 17 because it breaks the layout when the view is presented
            if #available(iOS 18.0, *) {
                $0.presentationBackground(Color(.systemBackground))
            } else {
                $0
            }
        }
        .accentColor(theme.colors.primary)
        .navigationViewStyle(.stack)
        .onAppear {
            octopus.core.toastsRepository.resetDisplayedToasts()
            octopus.core.trackingRepository.octopusUISessionStarted()
            displayScreenAfterNotificationTapped(notificationUserInfo: notificationUserInfo)
            if !viewModel.displayCommunityAccessDenied {
                gamificationRulesViewManager.incrementViewCountIfNeeded()
            }
        }
        .onDisappear {
            octopus.core.toastsRepository.resetDisplayedToasts()
            octopus.core.trackingRepository.octopusUISessionEnded()
        }
        .onValueChanged(of: notificationUserInfo != nil) { hasValue in
            guard hasValue else { return }
            displayScreenAfterNotificationTapped(notificationUserInfo: notificationUserInfo)
        }
        .gamificationRulesSheet(
            isPresented: $gamificationRulesViewManager.shouldDisplayGamificationRules,
            gamificationConfig: gamificationRulesViewManager.gamificationConfig,
            gamificationRulesViewManager: gamificationRulesViewManager)
        // set the environment, this will set the default environment if no other has been set, and avoid re-creating
        // the default env each time it is accessed
        .environment(\.octopusTheme, theme)
        .environmentObject(translationStore)
        .environment(\.trackingApi, trackingApi)
        .environmentObject(gamificationRulesViewManager)
        .environmentObject(displayConfigManager)
        .environmentObject(videoManager)
        .environment(\.urlOpener, urlOpener)
        .environmentObject(languageManager)
        .overrideLanguageIfNeeded(languageManager: languageManager)
    }

    @ViewBuilder
    private var closeModalButton: some View {
        if presentationMode.wrappedValue.isPresented {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Common.Close", bundle: .module)
                    .font(theme.fonts.navBarItem)
            }
        }
    }

    private func displayScreenAfterNotificationTapped(notificationUserInfo: [AnyHashable: Any]?) {
        guard let notificationUserInfo else { return }
        defer { self.notificationUserInfo = nil }
        guard let action = octopus.core.notificationsRepository.getPushNotificationTappedAction(
            userInfo: notificationUserInfo) else { return }
        switch action {
        case let .open(contentsToOpen):
            viewModel.mainFlowPath.path = contentsToOpen.map { $0.mainFlowScreen }
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

// MARK: - Deprecated init
extension OctopusHomeScreen {
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

    // swiftlint:disable line_length
    /// Constructor of the `OctopusHomeScreen`.
    /// - Parameters:
    ///    - octopus: The Octopus SDK
    ///    - bottomSafeAreaInset: the bottom safe area inset. Default is 0. Only used on iOS 15+.
    ///    - mainFeedNavBarTitle: the title displayed in the navigation on the main feed screen.
    ///    - mainFeedColoredNavBar: whether the primary color should be used on the nav bar.
    ///    - postId: the id of the post to be directly displayed. If nil, post feed will be displayed.
    ///    - notificationResponse: a binding on the notification response.
    @available(*, deprecated, renamed: "init(octopus:bottomSafeAreaInset:mainFeedNavBarTitle:mainFeedColoredNavBar:initialScreen:notificationUserInfo:)")
    // swiftlint:enable line_length
    @_disfavoredOverload
    public init(octopus: OctopusSDK,
                bottomSafeAreaInset: CGFloat = 0,
                mainFeedNavBarTitle: OctopusMainFeedTitle? = nil,
                mainFeedColoredNavBar: Bool = false,
                postId: String? = nil,
                notificationResponse: Binding<UNNotificationResponse?> = .constant(nil)) {
        let screen: OctopusInitialScreen
        if let postId {
            screen = .post(.init(postId: postId))
        } else {
            screen = .mainFeed
        }
        self.init(
            octopus: octopus,
            bottomSafeAreaInset: bottomSafeAreaInset,
            mainFeedNavBarTitle: mainFeedNavBarTitle,
            mainFeedColoredNavBar: mainFeedColoredNavBar,
            initialScreen: screen,
            notificationUserInfo: Self.userInfoBinding(from: notificationResponse)
        )
    }

    // swiftlint:disable line_length
    /// Constructor of the `OctopusHomeScreen`.
    @available(*, deprecated, renamed: "init(octopus:bottomSafeAreaInset:mainFeedNavBarTitle:mainFeedColoredNavBar:initialScreen:notificationUserInfo:)")
    // swiftlint:enable line_length
    @_disfavoredOverload
    public init(octopus: OctopusSDK,
                bottomSafeAreaInset: CGFloat = 0,
                navBarLeadingItem: NavBarLeadingItemKind = .logo,
                navBarPrimaryColor: Bool = false,
                postId: String? = nil,
                notificationResponse: Binding<UNNotificationResponse?> = .constant(nil)) {
        let screen: OctopusInitialScreen
        if let postId {
            screen = .post(.init(postId: postId))
        } else {
            screen = .mainFeed
        }
        self.init(
            octopus: octopus,
            bottomSafeAreaInset: bottomSafeAreaInset,
            mainFeedNavBarTitle: navBarLeadingItem.toOctopusMainFeedTitle,
            mainFeedColoredNavBar: navBarPrimaryColor,
            initialScreen: screen,
            notificationUserInfo: Self.userInfoBinding(from: notificationResponse)
        )
    }
}

extension OctopusHomeScreen.NavBarLeadingItemKind {
    var toOctopusMainFeedTitle: OctopusMainFeedTitle {
        switch self {
        case .logo: .init(content: .logo, placement: .leading)
        case let .text(text): .init(content: .text(.init(text: text.text)), placement: .leading)

        }
    }
}

// MARK: - Deprecated binding bridge

private extension OctopusHomeScreen {
    /// Maps a `Binding<UNNotificationResponse?>` owned by a host app into a
    /// `Binding<[AnyHashable: Any]?>` that the new init consumes.
    ///
    /// The SDK only ever writes `nil` back to signal consumption. Writing a non-nil
    /// dict back is not supported: `UNNotificationResponse` has no public initializer,
    /// so we cannot round-trip a dict into a response.
    static func userInfoBinding(
        from responseBinding: Binding<UNNotificationResponse?>
    ) -> Binding<[AnyHashable: Any]?> {
        Binding<[AnyHashable: Any]?>(
            get: { responseBinding.wrappedValue?.notification.request.content.userInfo },
            set: { newValue in
                if newValue == nil { responseBinding.wrappedValue = nil }
            }
        )
    }
}
