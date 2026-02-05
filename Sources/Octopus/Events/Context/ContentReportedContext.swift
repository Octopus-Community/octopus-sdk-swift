//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .contentReported
    public protocol ContentReportedContext: Sendable {
        /// The id of the content
        var contentId: String { get }
        /// The reasons of reporting this content
        var reasons: [ReportReason] { get }
    }
}

extension SdkEvent.ContentReportedContext: OctopusEvent.ContentReportedContext {
    public var reasons: [OctopusEvent.ReportReason] { coreReasons.map { .init(from: $0) } }
}
