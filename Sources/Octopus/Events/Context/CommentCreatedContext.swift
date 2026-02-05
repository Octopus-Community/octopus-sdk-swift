//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .commentCreated
    public protocol CommentCreatedContext: Sendable {
        /// The id of the comment.
        var commentId: String { get }
        /// The id of the post in which the comment has been posted
        var postId: String { get }
        /// The length of the text of this comment
        var textLength: Int { get }
    }
}

extension SdkEvent.CommentCreatedContext: OctopusEvent.CommentCreatedContext { }
