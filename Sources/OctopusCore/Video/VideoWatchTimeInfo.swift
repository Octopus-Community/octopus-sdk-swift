//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public struct VideoWatchTimeInfo {
    public let contentId: String
    public let videoId: String
    public let duration: TimeInterval
    public internal(set) var currentWatchTime: TimeInterval
    public internal(set) var completionCount: Int

    var totalWatchTime: TimeInterval {
        guard completionCount > 0 else { return currentWatchTime }
        return currentWatchTime + (TimeInterval(completionCount) * duration)
    }
}
