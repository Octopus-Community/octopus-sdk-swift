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
/// - a publisher of the push userInfo when an Octopus notification is tapped
/// - a function to ask for notification permission
/// It is here because, due to the multiple way of initializing the SDK, it is not created in the AppDelegate as you
/// should do it. If you create the SDK in your AppDelegate, you can directly call the function
/// `octopus.set(notificationDeviceToken:)` when receiving the device token.
class NotificationManager: ObservableObject {

    static let instance = NotificationManager()

    @Published private(set) var notificationDeviceToken: String?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus?
    @Published private(set) var handleOctopusNotificationUserInfo: [AnyHashable: Any]?

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

    /// Asks for the notification permission once the SDK is started, like the Android sample. iOS only shows the
    /// prompt while the status is not determined, so a later launch or a denial stays silent; after a denial only
    /// the system Settings bring the permission back (the Push Token scenario links to them).
    func requestForPushNotificationPermissionIfNotDetermined() {
        Task {
            guard await notifCenter.notificationSettings().authorizationStatus == .notDetermined else { return }
            requestForPushNotificationPermission()
        }
    }

    func handle(notificationResponse: UNNotificationResponse) {
        let userInfo = notificationResponse.notification.request.content.userInfo
        if OctopusSDK.isAnOctopusNotification(userInfo: userInfo) {
            handleOctopusNotificationUserInfo = userInfo
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
