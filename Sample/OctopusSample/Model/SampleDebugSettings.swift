//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Debug switches the sample keeps across launches, so a QA session survives a relaunch.
///
/// Sample-only: none of this reaches the SDK's published surface.
enum SampleDebugSettings {
    private static let forceOfflineKey = "OctopusSample.debug.forceOffline"

    /// Whether the SDK is told it has no connection, whatever the device says. A simulator always
    /// reports a connection, so this is the only way to reach the offline screen states there.
    static var forceOffline: Bool {
        get { UserDefaults.standard.bool(forKey: forceOfflineKey) }
        set { UserDefaults.standard.set(newValue, forKey: forceOfflineKey) }
    }
}
