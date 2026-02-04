//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .sessionStarted
    public protocol SessionStartedContext: Sendable {
        /// The id of the session
        var sessionId: String { get }
    }
}

extension SdkEvent.SessionStartedContext: OctopusEvent.SessionStartedContext { }
