//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import OSLog

@available(iOS 14.0, *)
extension Logger {
    private static let subsystem = "\(Bundle.main.bundleIdentifier ?? "").octopusSDK.core"

    /// Logs that are related the user connection
    static let connection = Logger(subsystem: subsystem, category: "Connection")
    /// Logs that are related to feeds
    static let feed = Logger(subsystem: subsystem, category: "Feed")
    /// Logs that are related to contents (Post, Comments, Reply)
    static let content = Logger(subsystem: subsystem, category: "Contents")
    /// Logs that are related to comments
    static let comments = Logger(subsystem: subsystem, category: "Comments")
    /// Logs that are related to posts
    static let posts = Logger(subsystem: subsystem, category: "Posts")
    /// Logs that are related to the profile
    static let profile = Logger(subsystem: subsystem, category: "Profile")
    /// Logs that are related to internal stuffs
    static let other = Logger(subsystem: subsystem, category: "Other")
}
