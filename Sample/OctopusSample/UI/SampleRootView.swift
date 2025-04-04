//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusUI
import Octopus

struct SampleRootView: View {
    private enum Tab: Int, Hashable {
        case modal
        case embedded
        case more
    }

    private let savedSelectedTabKey = "savedSelectedTab"

    // First value is true if we are in internal demo mode.
    @State private var openOctopusAsModal: Bool
    @State private var selectedTab: Tab// = Tab.modal

    init() {
        let savedSelectedTab = Tab(rawValue: UserDefaults.standard.integer(forKey: savedSelectedTabKey)) ?? .modal
        _selectedTab = State(initialValue: savedSelectedTab)
        _openOctopusAsModal = State(initialValue: savedSelectedTab == .modal ? DefaultValuesProvider.demoMode : false)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // This example shows you that you can display an OctopusHomeScreen as a full screen modal
            NavigationView {
                VStack(spacing: 30) {
                    Spacer()
                    Text("This is your app's content")
                    Button("Open Octopus Home Screen as full screen modal") {
                        openOctopusAsModal = true
                    }
                    Spacer()
                    Text("App Version: \(versionStr)")
                        .bold()
                        .padding()
                }
                .fullScreenCover(isPresented: $openOctopusAsModal) {
                    // Init of OctopusSDK should be done as soon as possible in your app (in your AppDelegate for example)
                    // This is not what we do here because this sample showcases multiple way of initializing the SDK.
                    let octopus = try! OctopusSDK(
                        apiKey: APIKeys.octopusAuth,
                        connectionMode: .octopus(deepLink: "com.octopuscommunity.sample://magic-link")
                    )
                    OctopusHomeScreen(octopus: octopus)
                        // only for used for internal purpose, you can ignore this for the easiest way to use Octopus
                        // If you want to override the theme, please have a look to Scenarios/CustomTheme
                        .modify {
                            if DefaultValuesProvider.demoMode {
                                $0.environment(\.octopusTheme, demoTheme)
                            } else { $0 }
                        }
                }
            }
            .tabItem {
                Text("Modal")
            }.tag(Tab.modal)

            // This example shows you that you can display an OctopusHomeScreen as view
            Group {
                if selectedTab == .embedded {
                    // Init of OctopusSDK should be done as soon as possible in your app (in your AppDelegate for example)
                    // This is not what we do here because this sample showcases multiple way of initializing the SDK.
                    let octopus = try! OctopusSDK(apiKey: APIKeys.octopusAuth)
                    // You can pass a `bottomSafeAreaInset` in order to add some safe area at the bottom of `OctopusHomeScreen`.
                    OctopusHomeScreen(octopus: octopus, bottomSafeAreaInset: 10)
                } else {
                    Text("Loading")
                }
            }
            .tabItem {
                Text("Octo Tab")
            }.tag(Tab.embedded)

            // Entry point for a list of specific, advanced examples
            NavigationView {
                ScenariosView()
            }
            .tabItem {
                Text("More")
            }.tag(Tab.more)
        }
        .onAppear() {
            UITabBar.appearance().barTintColor = UIColor.systemGroupedBackground
            UITabBar.appearance().backgroundColor = UIColor.systemGroupedBackground
        }
        .onValueChanged(of: selectedTab) {
            UserDefaults.standard.set($0.rawValue, forKey: savedSelectedTabKey)
        }
    }

    var versionStr: String {
        let appVersion = (Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)
        let buildNumber = (Bundle.main.infoDictionary!["CFBundleVersion"] as! String)
        return "\(appVersion) (#\(buildNumber))"
    }

    let demoTheme = OctopusTheme(
        colors: .init(
            primarySet: OctopusTheme.Colors.ColorSet(
                main: .InternalDemo.primary,
                lowContrast: .InternalDemo.primaryLow,
                highContrast: .InternalDemo.primaryHigh)))
}

#Preview {
    SampleRootView()
}
