//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient

/// Process-wide record of the SDK the host app integrates, read on every gRPC call.
///
/// Native by default. A wrapper SDK (Flutter, React Native, Unity) replaces it through
/// `OctopusSDK.setSdkFamily(_:version:)`, normally once and before creating `OctopusSDK`; a later call applies
/// from the next request. It is process-wide rather than per `OctopusSDK` instance so that it survives a
/// community switch, which rebuilds the core.
package final class SdkIdentityRegistry: @unchecked Sendable {
    /// The registry the SDK reads.
    package static let shared = SdkIdentityRegistry()

    // `Mutex` and `OSAllocatedUnfairLock` need iOS 18 / 16; the SDK targets iOS 13.
    private let lock = NSLock()
    private var identity = SdkIdentity(family: .native, version: version)

    init() {}

    /// The identity to report on the next gRPC call.
    var current: SdkIdentity {
        lock.lock()
        defer { lock.unlock() }
        return identity
    }

    /// Replaces the reported identity. The last call wins.
    func set(family: SdkIdentity.Family, version: String) {
        lock.lock()
        defer { lock.unlock() }
        identity = SdkIdentity(family: family, version: version)
    }
}
