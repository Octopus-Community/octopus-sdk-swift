//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import UIKit

/// When to read again what could not be read before the device's first unlock after a reboot (the Keychain, the
/// databases' files): the device being unlocked, and the app coming back, which covers that notification being missed
/// while the app was suspended.
enum ProtectedDataTriggers {
    static var `default`: AnyPublisher<Void, Never> {
        Publishers.MergeMany(
            [UIApplication.protectedDataDidBecomeAvailableNotification,
             UIApplication.willEnterForegroundNotification,
             UIApplication.didBecomeActiveNotification]
                .map { NotificationCenter.default.publisher(for: $0).map { _ in }.eraseToAnyPublisher() }
        ).eraseToAnyPublisher()
    }
}
