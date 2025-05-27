//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that displays the Octopus UI in a full screen modal
struct ModalOctopusAuthView: View {
    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()
    @Binding var openOctopusAsModal: Bool

    @State private var octopusNotification: UNNotificationResponse?

    var body: some View {
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
            if let octopus = viewModel.octopus {
                OctopusHomeScreen(octopus: octopus)
                // only for used for internal purpose, you can ignore this for the easiest way to use Octopus
                // If you want to override the theme, please have a look to Scenarios/CustomTheme
                    .modify {
                        if DefaultValuesProvider.demoMode {
                            $0.environment(\.octopusTheme, demoTheme)
                        } else { $0 }
                    }
            } else {
                EmptyView()
            }
        }
        .onAppear {
            viewModel.createSDK()
        }
    }

    var versionStr: String {
        let appVersion = (Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)
        let buildNumber = (Bundle.main.infoDictionary!["CFBundleVersion"] as! String)
        return "\(appVersion) (#\(buildNumber))"
    }

    // Only for used for internal purpose
    // If you want to override the theme, please have a look to Scenarios/CustomTheme
    let demoTheme = OctopusTheme(
        colors: .init(
            primarySet: OctopusTheme.Colors.ColorSet(
                main: .InternalDemo.primary,
                lowContrast: .InternalDemo.primaryLow,
                highContrast: .InternalDemo.primaryHigh)))
}


