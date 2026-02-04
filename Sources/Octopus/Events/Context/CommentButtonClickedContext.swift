//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .commentButtonClicked
    public protocol CommentButtonClickedContext: Sendable {
        /// The id of the post
        var postId: String { get }
    }
}

extension SdkEvent.CommentButtonClickedContext: OctopusEvent.CommentButtonClickedContext { }
