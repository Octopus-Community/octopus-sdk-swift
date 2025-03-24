//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import OSLog

@available(iOS 14.0, *)
extension Logger {
    private static let subsystem = "\(Bundle.main.bundleIdentifier ?? "").octopusSDK.remote"

    /// Received messages
    static let received = Logger(subsystem: subsystem, category: "Received")
    /// Sent messages
    static let sent = Logger(subsystem: subsystem, category: "Sent")
}
