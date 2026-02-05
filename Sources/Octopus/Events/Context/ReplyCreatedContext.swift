//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .replyCreated
    public protocol ReplyCreatedContext: Sendable {
        /// The id of the reply.
        var replyId: String { get }
        /// The id of the comment in which this reply has been posted
        var commentId: String { get }
        /// The length of the text of this reply
        var textLength: Int { get }
    }
}

extension SdkEvent.ReplyCreatedContext: OctopusEvent.ReplyCreatedContext { }
