//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusUI
import Octopus

struct SampleRootView: View {
    private enum Tab: Hashable {
        case modal
        case embedded
        case more
    }

    @ObservedObject var model = SampleModel()

    // First value is true if we are in internal demo mode.
    @State private var openOctopusAsModal = DefaultValuesProvider.demoMode
    @State private var selectedTab = Tab.modal

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
                    OctopusHomeScreen(octopus: model.octopus)
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
            OctopusHomeScreen(octopus: model.octopus)
            .tabItem {
                Text("Octo Tab")
            }.tag(Tab.embedded)

            // Entry point for a list of specific, advanced examples
            NavigationView {
                ScenariosView(model: model)
            }
            .tabItem {
                Text("More")
            }.tag(Tab.more)
        }.onAppear() {
            UITabBar.appearance().barTintColor = UIColor.systemGroupedBackground
            UITabBar.appearance().backgroundColor = UIColor.systemGroupedBackground
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
