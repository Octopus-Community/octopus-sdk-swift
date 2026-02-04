//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusUI
import Octopus
import OctopusCore

struct SampleTabView: View {
    private enum Tab: Int, Hashable {
        case modal
        case embedded
        case more
        case account
    }

    private let savedSelectedTabKey = "savedSelectedTab"

    // First value is true if we are in internal demo mode.
    @State private var openOctopusAsModal: Bool
    @State private var selectedTab: Tab

    @State private var fullScreenItem: ScreenBuilder?
    @State private var sheetScreenItem: ScreenBuilder?

    @State private var id = UUID()

    init() {
        let savedSelectedTab = Tab(rawValue: UserDefaults.standard.integer(forKey: savedSelectedTabKey)) ?? .modal
        _selectedTab = State(initialValue: savedSelectedTab)
        _openOctopusAsModal = State(initialValue: savedSelectedTab == .modal ? DefaultValuesProvider.internalDemoMode : false)
        _ = AppUserManager.instance // only here to force the AppUserManager instance to be started
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // This example shows you that you can display an OctopusHomeScreen as a full screen modal
            ModalOctopusAuthView(openOctopusAsModal: $openOctopusAsModal)
                .tabItem {
                    VStack {
                        Image(systemName: "building.2")
                        Text("Modal")
                    }

                }.tag(Tab.modal)

            // This example shows you that you can display an OctopusHomeScreen as view
            EmbeddedOctopusAuthView()
                .tabItem {
                    VStack {
                        Image(systemName: "building")
                        Text("Octo Tab")
                    }
                }.tag(Tab.embedded)

            // Entry point for a list of specific, advanced examples
            ScenariosView(
                showFullScreen: {
                    fullScreenItem = ScreenBuilder(builder: $0)
                },
                showInSheet: {
                    sheetScreenItem = ScreenBuilder(builder: $0)
                }
            )
            .tabItem {
                VStack {
                    Image(systemName: "ellipsis")
                    Text("More")
                }
            }.tag(Tab.more)

            if shouldDisplayAccountTab {
                AccountView()
                    .tabItem {
                        VStack {
                            Image(systemName: "person.crop.circle")
                            Text("Account")
                        }
                    }
                    .tag(Tab.account)
                    .id(id) // to recompute if we need to display it
            }
        }
        .modify {
            // only apply UITabbar color appearance on iOS < 26
#if compiler(>=6.2)
            if #available(iOS 26.0, *) { $0 } else {
                $0.onAppear() {
                    UITabBar.appearance().barTintColor = UIColor.systemGroupedBackground
                    UITabBar.appearance().backgroundColor = UIColor.systemGroupedBackground
                }
            }
#else
            $0.onAppear() {
                UITabBar.appearance().barTintColor = UIColor.systemGroupedBackground
                UITabBar.appearance().backgroundColor = UIColor.systemGroupedBackground
            }
#endif
        }
        .onValueChanged(of: selectedTab) {
            UserDefaults.standard.set($0.rawValue, forKey: savedSelectedTabKey)
        }
        .fullScreenCover(item: $fullScreenItem) {
            AnyView($0.builder())
        }
        .sheet(item: $sheetScreenItem) {
            AnyView($0.builder())
        }
        .onReceive(NotificationManager.instance.$handleOctopusNotification) {
            guard $0 != nil else { return }
            // when a notification is received, we display the Octopus UI
            selectedTab = .modal
            openOctopusAsModal = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiKeyChanged)) { _ in
            id = UUID()
        }
    }

    var shouldDisplayAccountTab: Bool {
        switch SDKConfigManager.instance.sdkConfig?.authKind {
        case .octopus: return false
        default: return true
        }
    }
}


// Wrapper to store any view with an ID
private struct ScreenBuilder: Identifiable {
    let id = UUID()
    let builder: () -> any View
}

#Preview {
    SampleTabView()
}
