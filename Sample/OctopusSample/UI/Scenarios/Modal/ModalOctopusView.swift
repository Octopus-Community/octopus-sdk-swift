//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that displays the Octopus UI in a full screen modal
struct ModalOctopusView: View {
    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()
    @Binding var openOctopusAsModal: Bool

    @Environment(\.sizeCategory) var sizeCategory // make it recompute the theme when the size category changes

    @State private var octopusNotificationUserInfo: [AnyHashable: Any]?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("This is your app's content")
                    .font(.headline)

                Button(action: { openOctopusAsModal = true }) {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("Open the Octopus Community")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)
                }

                notificationButton
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 4) {
                if let sdkConfig = SDKConfigManager.instance.sdkConfig {
                    Text("SDK configured with: \(sdkConfig.displayableString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("App Version: \(versionStr)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $openOctopusAsModal) {
            OctopusUIView(
                octopus: viewModel.octopus,
                octopusNotificationUserInfo: $octopusNotificationUserInfo
            )
            // only for used for internal purpose, you can ignore this for the easiest way to use Octopus
            // If you want to override the theme, please have a look to Scenarios/CustomTheme
            .modify {
                if DefaultValuesProvider.internalDemoMode {
                    $0.environment(\.octopusTheme, demoTheme)
                } else { $0 }
            }
            .connectionErrorAlert()
        }
        .onReceive(NotificationManager.instance.$handleOctopusNotificationUserInfo) {
            octopusNotificationUserInfo = $0
        }
    }

    @ViewBuilder
    private var notificationButton: some View {
        switch viewModel.authorizationStatus {
        case .notDetermined:
            Button(action: viewModel.askForNotificationPermission) {
                HStack {
                    Image(systemName: "bell")
                    Text("Ask for notification permission")
                }
                .font(.subheadline)
            }
        case .denied:
            Button(action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }) {
                HStack {
                    Image(systemName: "bell.slash")
                    Text("Notifications denied. Tap to open Settings.")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
            }
        default:
            Button(action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }) {
                HStack {
                    Image(systemName: "bell.badge")
                    Text("Notifications enabled. Tap to open Settings.")
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
        }
    }

    var versionStr: String {
        let appVersion = (Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)
        let buildNumber = (Bundle.main.infoDictionary!["CFBundleVersion"] as! String)
        return "\(appVersion) (#\(buildNumber))"
    }

    // Only for used for internal purpose
    // If you want to override the theme, please have a look to Scenarios/CustomTheme
    var demoTheme: OctopusTheme { OctopusTheme(
        colors: .init(
            primarySet: OctopusTheme.Colors.ColorSet(
                main: .InternalDemo.primary,
                lowContrast: .InternalDemo.primaryLow,
                highContrast: .InternalDemo.primaryHigh)))
    }
}
