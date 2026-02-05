//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct ContentReportedContext: Sendable {
        /// The id of the content
        public let contentId: String
        /// The reasons of reporting this content
        public let coreReasons: [ReportReason]
    }
}

