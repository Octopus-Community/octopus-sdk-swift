//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .sessionStopped
    public protocol SessionStoppedContext: Sendable {
        /// The id of the session
        var sessionId: String { get }
    }
}

extension SdkEvent.SessionStoppedContext: OctopusEvent.SessionStoppedContext { }
