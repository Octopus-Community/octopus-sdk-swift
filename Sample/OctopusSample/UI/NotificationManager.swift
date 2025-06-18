//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit
import Combine
import Octopus

/// This class is a singleton that provides functions to handle notifications:
/// - a publisher of the notification device token
/// - a function to open Octopus UI in case of Octopus notification opened
/// - a function to ask for notification permission
/// It is here because, due to the multiple way of initializing the SDK, it is not created in the AppDelegate as you
/// should do it. If you create the SDK in your AppDelegate, you can directly call the function
/// `octopus.set(notificationDeviceToken:)` when receiving the device token.
class NotificationManager {

    static let instance = NotificationManager()

    @Published private(set) var notificationDeviceToken: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus?
    @Published private(set) var handleOctopusNotification: UNNotificationResponse?

    /// The notification center
    private let notifCenter = UNUserNotificationCenter.current()
    private var storage = [AnyCancellable]()

    private init() {
        updateAuthorizationStatus()
        registerForRemoteNotificationsIfAuthorized()

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in updateAuthorizationStatus() }
            .store(in: &storage)
    }

    func set(notificationDeviceToken: String) {
        self.notificationDeviceToken = notificationDeviceToken
    }

    func requestForPushNotificationPermission() {
        Task {
            do {
                print("requestForPushNotificationPermission")
                if await notifCenter.notificationSettings().authorizationStatus != .authorized {
                    print("authorizationStatus != .authorized")
                    if try await notifCenter.requestAuthorization(options: [.alert, .badge, .sound]) {
                        print("requestAuthorization called")
                        // register for notifications if the authorization has just been asked
                        DispatchQueue.main.async {
                            print("register called")
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }

                }
            } catch {
                print("Error while requesting for push notification permission: \(error)")
            }
            await updateAuthorizationStatus()
        }
    }

    func handle(notificationResponse: UNNotificationResponse) {
        if OctopusSDK.isAnOctopusNotification(notification: notificationResponse.notification) {
            handleOctopusNotification = notificationResponse
        } else {
            // This is a notification for your app, do what you want
        }
    }

    private func registerForRemoteNotificationsIfAuthorized() {
        Task {
            if await notifCenter.notificationSettings().authorizationStatus == .authorized {
                await UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func updateAuthorizationStatus() {
        Task { await updateAuthorizationStatus() }
    }

    private func updateAuthorizationStatus() async {
        let newAuthorizationStatus = await notifCenter.notificationSettings().authorizationStatus
        await MainActor.run {
            authorizationStatus = newAuthorizationStatus
        }
    }
}
