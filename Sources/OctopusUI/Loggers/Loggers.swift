//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import OSLog

@available(iOS 14.0, *)
extension Logger {
    private static let subsystem = "\(Bundle.main.bundleIdentifier ?? "").octopusSDK.ui"

    /// Logs that are related the images
    static let images = Logger(subsystem: subsystem, category: "Images")
    /// Logs that are related to feeds
    static let feed = Logger(subsystem: subsystem, category: "Feed")
    /// Logs that are related to comments
    static let comments = Logger(subsystem: subsystem, category: "Comments")
    /// Logs that are related to replies
    static let replies = Logger(subsystem: subsystem, category: "Replies")
    /// Logs that are related to posts
    static let posts = Logger(subsystem: subsystem, category: "Posts")
    /// Logs that are related to the profile
    static let profile = Logger(subsystem: subsystem, category: "Profile")
    /// Logs that are related to the notifications
    static let notifs = Logger(subsystem: subsystem, category: "Notifications")
    /// Logs that are related to the config
    static let config = Logger(subsystem: subsystem, category: "Config")
    /// Logs that are related to the video
    static let video = Logger(subsystem: subsystem, category: "Video")
    /// Logs that are related to general stuff
    static let general = Logger(subsystem: subsystem, category: "General")
}
