//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .replyButtonClicked
    public protocol ReplyButtonClickedContext: Sendable {
        /// The id of the comment
        var commentId: String { get }
    }
}

extension SdkEvent.ReplyButtonClickedContext: OctopusEvent.ReplyButtonClickedContext { }
