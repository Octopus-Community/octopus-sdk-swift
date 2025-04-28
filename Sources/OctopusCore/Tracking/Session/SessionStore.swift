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
        uuidKey = "\(prefix).uuid"
        startTimestampKey = "\(prefix).startTimestamp"
        firstSessionKey = "\(prefix).firstSession"
        lastKnownTimestampKey = "\(prefix).lastKnownTimestamp"

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
}
