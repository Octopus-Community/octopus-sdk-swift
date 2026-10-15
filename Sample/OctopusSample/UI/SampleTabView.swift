//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusUI
import Octopus
import OctopusCore

/// The sample shell: three tabs, Scenarios · Community · Settings, in the order and with the test ids of the
/// Android sample. The app always starts on Scenarios.
///
/// - Scenarios and Settings are host-app screens, each in its own navigation container.
/// - Community hosts `OctopusHomeScreen` directly, with no container around it (the SDK owns its navigation),
///   or, in the Full screen `CommunityNavigation` mode, presents it above the tabs.
///
/// Every tab stays alive while another one is shown, so each keeps its own navigation stack. Full screen and
/// sheet presentations are owned here so they escape the tabs' navigation.
struct SampleTabView: View {
    @ObservedObject private var router = SampleTabRouter.instance
    @StateObjectCompat private var communityBadge = CommunityTabBadgeViewModel()

    @State private var fullScreenItem: ScreenBuilder?
    @State private var sheetScreenItem: ScreenBuilder?

    init() {
        _ = AppUserManager.instance // only here to force the AppUserManager instance to be started
    }

    var body: some View {
        tabView
            .tint(SampleTokens.Colors.accentText)
            .sampleTabBarNeverMinimize()
            .modify {
                // only apply UITabbar color appearance on iOS < 26
#if compiler(>=6.2)
                if #available(iOS 26.0, *) { $0 } else {
                    $0.onAppear {
                        UITabBar.appearance().barTintColor = UIColor.systemGroupedBackground
                        UITabBar.appearance().backgroundColor = UIColor.systemGroupedBackground
                    }
                }
#else
                $0.onAppear {
                    UITabBar.appearance().barTintColor = UIColor.systemGroupedBackground
                    UITabBar.appearance().backgroundColor = UIColor.systemGroupedBackground
                }
#endif
            }
            .fullScreenCover(isPresented: $router.isCommunityFullScreenPresented) {
                CommunityFullScreenView(octopusNotificationUserInfo: $router.pendingNotificationUserInfo)
            }
            .fullScreenCover(item: $fullScreenItem) {
                AnyView($0.builder())
            }
            .sheet(item: $sheetScreenItem) {
                AnyView($0.builder())
            }
            .onAppear {
                communityBadge.refresh()
            }
            .onReceive(NotificationManager.instance.$handleOctopusNotificationUserInfo) {
                guard let userInfo = $0 else { return }
                // The shell is the only consumer of a tapped push: it closes any open scenario presentation
                // and hands the payload to the community of the current navigation mode, once.
                router.routeNotification(userInfo: userInfo)
            }
            .onReceive(router.dismissPresentations) { _ in
                fullScreenItem = nil
                sheetScreenItem = nil
            }
            .connectionErrorAlert()
    }

    /// `Tab` values on iOS 18+ (the API the iOS 26 tab bar is built for), `tabItem` before. Both carry the
    /// same three tabs, ids and badge.
    @ViewBuilder
    private var tabView: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: selection) {
                Tab(value: SampleTab.scenarios) { scenariosTab } label: { tabLabel(.scenarios) }
                Tab(value: SampleTab.community) { communityTab } label: { tabLabel(.community) }
                    .badge(communityBadgeText)
                Tab(value: SampleTab.settings) { settingsTab } label: { tabLabel(.settings) }
            }
        } else {
            TabView(selection: selection) {
                scenariosTab
                    .tabItem { tabLabel(.scenarios) }
                    .tag(SampleTab.scenarios)
                communityTab
                    .tabItem { tabLabel(.community) }
                    .badge(communityBadgeText)
                    .tag(SampleTab.community)
                settingsTab
                    .tabItem { tabLabel(.settings) }
                    .tag(SampleTab.settings)
            }
        }
    }

    /// Every tab bar tap goes through the router, a tap on the tab already selected included: that is how
    /// a second tap on Community brings the SDK back to its feed.
    private var selection: Binding<SampleTab> {
        Binding(get: { router.selectedTab }, set: { router.select($0) })
    }

    // Entry point for a list of specific, advanced examples
    private var scenariosTab: some View {
        SampleNavigationContainer {
            ScenariosView(
                showFullScreen: { fullScreenItem = ScreenBuilder(builder: $0) },
                showInSheet: { sheetScreenItem = ScreenBuilder(builder: $0) }
            )
        }
        // Scenarios is the launch tab, so its content is always loaded first: it sets the ids of all three.
        .sampleTabBarIdentifiers(SampleTab.allCases.map(\.accessibilityId))
    }

    // This example shows you that you can display an OctopusHomeScreen as a tab of your app
    private var communityTab: some View {
        CommunityTabView(router: router)
    }

    private var settingsTab: some View {
        SampleNavigationContainer {
            SettingsView()
        }
    }

    private var communityBadgeText: Text? {
        communityBadge.badgeText.map { Text(verbatim: $0) }
    }

    private func tabLabel(_ tab: SampleTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
    }
}

// Wrapper to store any view with an ID
private struct ScreenBuilder: Identifiable {
    let id = UUID()
    let builder: () -> any View
}
