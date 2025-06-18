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
            switch viewModel.authorizationStatus {
            case .notDetermined:
                Button(action: viewModel.askForNotificationPermission) {
                    Text("Ask for notification permission")
                }
            case .denied:
                Button(action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }) {
                    Text("Notification permission is denied. Tap here to go to the system settings to enable it.")
                }
            default:
                Button(action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }) {
                    Text("Notification permission granted. Tap here to go to the system settings to change it.")
                }
            }
            Spacer()
            Text("App Version: \(versionStr)")
                .bold()
                .padding()
        }
        .fullScreenCover(isPresented: $openOctopusAsModal) {
            if let octopus = viewModel.octopus {
                OctopusHomeScreen(octopus: octopus, notificationResponse: $octopusNotification)
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
        .onReceive(NotificationManager.instance.$handleOctopusNotification) {
            octopusNotification = $0
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


