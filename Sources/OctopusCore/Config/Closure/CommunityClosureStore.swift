//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CryptoKit

/// Where the closure of a community is kept, one per API key.
///
/// Read synchronously at init, so that the calls are blocked before the first one can leave. Kept in the user
/// defaults rather than a database: it must survive both the purge of a closure and the teardown of a community
/// switch. The key holds the SHA-256 of the API key, not the API key itself: the user defaults are shared with the
/// host app and its other SDKs, and saved with the device backups.
final class CommunityClosureStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    private(set) var closure: CommunityClosure?

    init(apiKey: String, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let fingerprint = SHA256.hash(data: Data(apiKey.utf8)).map { String(format: "%02x", $0) }.joined()
        key = "OctopusSDK.CommunityClosure.\(fingerprint)"
        closure = userDefaults.data(forKey: key).flatMap { try? JSONDecoder().decode(CommunityClosure.self, from: $0) }
    }

    func set(_ closure: CommunityClosure?) {
        self.closure = closure
        if let data = closure.flatMap({ try? JSONEncoder().encode($0) }) {
            userDefaults.set(data, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// Whether the purge of the closure has yet to end: set before the closure is published, cleared once the purge
    /// ended, so that a purge the app was killed in, or that failed, is done again.
    var isPurgePending: Bool { userDefaults.bool(forKey: purgePendingKey) }

    func set(purgePending: Bool) {
        if purgePending {
            userDefaults.set(true, forKey: purgePendingKey)
        } else {
            userDefaults.removeObject(forKey: purgePendingKey)
        }
    }

    private var purgePendingKey: String { "\(key).purgePending" }
}
