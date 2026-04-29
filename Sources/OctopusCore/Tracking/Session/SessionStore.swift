//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A storable session
struct StorableSession {
    let uuid: String
    let startTimestamp: Double
    let firstSession: Bool
    let lastKnownTimestamp: Double
}

/// Class that stores sessions on the UserDefault
class SessionStore {

    @Published var session: StorableSession?

    private let userDefaults = UserDefaults.standard

    private let prefix: String
    private let uuidKey: String
    private let startTimestampKey: String
    private let firstSessionKey: String
    private let lastKnownTimestampKey: String

    required init(prefix: String) {
        self.prefix = "OctopusSDK.tracking.\(prefix)"
        uuidKey = "\(self.prefix).uuid"
        startTimestampKey = "\(self.prefix).startTimestamp"
        firstSessionKey = "\(self.prefix).firstSession"
        lastKnownTimestampKey = "\(self.prefix).lastKnownTimestamp"

        migrateUserDefaultsIfNeeded()

        session = loadSession()
    }

    private func loadSession() -> StorableSession? {
        guard let uuid = userDefaults.string(forKey: uuidKey),
              let startTimestamp = userDefaults.object(forKey: startTimestampKey) as? Double,
              let lastKnownTimestamp = userDefaults.object(forKey: lastKnownTimestampKey) as? Double,
              let firstSession = userDefaults.object(forKey: firstSessionKey) as? Bool
        else {
            return nil
        }
        return StorableSession(uuid: uuid,
                               startTimestamp: startTimestamp,
                               firstSession: firstSession,
                               lastKnownTimestamp: lastKnownTimestamp)
    }

    func store(session: StorableSession?) {
        userDefaults.set(session?.uuid, forKey: uuidKey)
        userDefaults.set(session?.startTimestamp, forKey: startTimestampKey)
        userDefaults.set(session?.firstSession, forKey: firstSessionKey)
        userDefaults.set(session?.lastKnownTimestamp, forKey: lastKnownTimestampKey)

        self.session = session
    }

    /// This function is here because there was a bug up until the 1.9.3 where the prefix was missing the
    /// `OctopusSDK.tracking.`
    ///
    /// This function transfers the previous data to the new keys, containing the correct prefix.
    private func migrateUserDefaultsIfNeeded() {
        let octopusPrefix = prefix.replacingOccurrences(of: "OctopusSDK.tracking.", with: "")
        let oldUuidKey = "\(octopusPrefix).uuid"
        let oldStartTimestampKey = "\(octopusPrefix).startTimestamp"
        let oldLastKnownTimestampKey = "\(octopusPrefix).lastKnownTimestamp"
        let oldFirstSessionKey = "\(octopusPrefix).firstSession"

        guard let uuid = userDefaults.string(forKey: oldUuidKey),
              let startTimestamp = userDefaults.object(forKey: oldStartTimestampKey) as? Double,
              let lastKnownTimestamp = userDefaults.object(forKey: oldLastKnownTimestampKey) as? Double,
              let firstSession = userDefaults.object(forKey: oldFirstSessionKey) as? Bool
        else {
            return
        }

        userDefaults.set(uuid, forKey: uuidKey)
        userDefaults.set(startTimestamp, forKey: startTimestampKey)
        userDefaults.set(firstSession, forKey: firstSessionKey)
        userDefaults.set(lastKnownTimestamp, forKey: lastKnownTimestampKey)

        userDefaults.removeObject(forKey: oldUuidKey)
        userDefaults.removeObject(forKey: oldStartTimestampKey)
        userDefaults.removeObject(forKey: oldLastKnownTimestampKey)
        userDefaults.removeObject(forKey: oldFirstSessionKey)
    }
}
