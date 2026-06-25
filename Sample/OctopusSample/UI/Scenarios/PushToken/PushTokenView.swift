//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

/// Displays the APNs device token registered by this build, with a button to copy it.
///
/// The token is populated by `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken` once the user
/// has granted the notification permission and the app has registered for remote notifications.
struct PushTokenView: View {
    @ObservedObject private var notificationManager = NotificationManager.instance
    @State private var copied = false

    var body: some View {
        List {
            Section(header: Text("APNs device token")) {
                if let token = notificationManager.notificationDeviceToken {
                    Text(token)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: { copy(token) }) {
                        Text(copied ? "Copied!" : "Copy token")
                    }
                } else {
                    Text("No device token yet. Grant the notification permission, then come back to this screen.")
                        .foregroundColor(.secondary)
                    if notificationManager.authorizationStatus != .authorized {
                        Button(action: { notificationManager.requestForPushNotificationPermission() }) {
                            Text("Ask for notification permission")
                        }
                    }
                }
            }
            Section {
                Text("""
                The token value does not reveal whether it is a sandbox or production token — that depends on \
                the build's aps-environment entitlement (Debug = development, Release/TestFlight = production).
                """)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.grouped)
        .navigationBarTitle(Text("Push Token"), displayMode: .inline)
    }

    private func copy(_ token: String) {
        UIPasteboard.general.string = token
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}
