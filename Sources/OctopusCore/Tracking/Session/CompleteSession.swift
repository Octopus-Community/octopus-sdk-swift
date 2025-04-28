//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A session that is completed (i.e. ended)
struct CompleteSession {
    let uuid: String
    let startDate: Date
    let endDate: Date
    let firstSession: Bool
}

extension CompleteSession {
    init?(from storableSession: StorableSession?) {
        guard let storableSession else { return nil }
        uuid = storableSession.uuid
        startDate = Date(timeIntervalSince1970: storableSession.startTimestamp)
        endDate = Date(timeIntervalSince1970: storableSession.lastKnownTimestamp)
        firstSession = storableSession.firstSession
    }

    var storableValue: StorableSession {
        .init(uuid: uuid,
              startTimestamp: startDate.timeIntervalSince1970,
              firstSession: firstSession,
              lastKnownTimestamp: endDate.timeIntervalSince1970)
    }
}
