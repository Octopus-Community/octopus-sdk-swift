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

    @State private var openOctopusAsModal = false
    @State private var selectedTab = Tab.more

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
}

#Preview {
    SampleRootView()
}
