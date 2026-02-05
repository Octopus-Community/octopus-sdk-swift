//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct SeeRepliesButtonClickedContext: Sendable {
        /// The id of the comment
        public let commentId: String

        public init(commentId: String) {
            self.commentId = commentId
        }
    }
}
