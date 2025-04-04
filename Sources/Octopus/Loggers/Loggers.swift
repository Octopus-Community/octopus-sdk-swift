//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import OSLog

@available(iOS 14.0, *)
extension Logger {
    private static let subsystem = "\(Bundle.main.bundleIdentifier ?? "").octopusSDK"

    /// Logs that are related the user connection
    static let connection = Logger(subsystem: subsystem, category: "Connection")
}
