//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UserNotifications
import OctopusDependencyInjection

extension Injected {
    static let userNotificationCenter = Injector.InjectedIdentifier<UserNotificationCenterProvider>()
}

protocol UserNotificationCenterProvider {
    func authorizationStatus() async -> UNAuthorizationStatus
}

class UserNotificationCenterProviderDefault: UserNotificationCenterProvider, InjectableObject {
    static let injectedIdentifier = Injected.userNotificationCenter

    private let notifCenter = UNUserNotificationCenter.current()

    init() { }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await notifCenter.notificationSettings().authorizationStatus
    }
}

