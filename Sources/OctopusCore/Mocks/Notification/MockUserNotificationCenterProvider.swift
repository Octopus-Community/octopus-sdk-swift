//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UserNotifications
import OctopusDependencyInjection

class MockUserNotificationCenterProvider: UserNotificationCenterProvider, InjectableObject {
    static let injectedIdentifier = Injected.userNotificationCenter

    private var authorizationStatusValue = UNAuthorizationStatus.notDetermined

    init() { }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func mockAutorizationStatus(_ status: UNAuthorizationStatus) {
        self.authorizationStatusValue = status
    }
}
