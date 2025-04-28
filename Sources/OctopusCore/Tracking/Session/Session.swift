//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A current session
struct Session {
    let uuid: String
    let startDate: Date
    let firstSession: Bool
    /// Last date where this session has been seen "alive"
    var lastHeartbeatDate: Date
}

extension Session {
    init?(from storableSession: StorableSession?) {
        guard let storableSession else { return nil }
        uuid = storableSession.uuid
        startDate = Date(timeIntervalSince1970: storableSession.startTimestamp)
        lastHeartbeatDate = Date(timeIntervalSince1970: storableSession.lastKnownTimestamp)
        firstSession = storableSession.firstSession
    }

    var storableValue: StorableSession {
        .init(uuid: uuid,
              startTimestamp: startDate.timeIntervalSince1970,
              firstSession: firstSession,
              lastKnownTimestamp: lastHeartbeatDate.timeIntervalSince1970)
    }

    func complete(useLastHeartbeatAsEndDate: Bool) -> CompleteSession {
        .init(uuid: uuid,
              startDate: startDate,
              endDate: useLastHeartbeatAsEndDate ? lastHeartbeatDate : Date(),
              firstSession: firstSession)
    }
}
