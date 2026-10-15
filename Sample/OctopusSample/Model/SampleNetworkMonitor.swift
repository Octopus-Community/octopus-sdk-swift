//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Network

/// Whether the device has a usable network path, as the Android sample's `rememberIsOnline`: Debug info prints it
/// next to the SDK status, so a report says whether the device or the backend was the one offline.
final class SampleNetworkMonitor: ObservableObject {
    static let instance = SampleNetworkMonitor()

    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async { self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "OctopusSample.network"))
    }

    /// "Online" or "Offline"; Force offline is the sample cutting the SDK off, so it reads as offline too and
    /// says why.
    static func label(isOnline: Bool, isForcedOffline: Bool) -> String {
        if isForcedOffline { return "Offline · forced" }
        return isOnline ? "Online" : "Offline"
    }
}
