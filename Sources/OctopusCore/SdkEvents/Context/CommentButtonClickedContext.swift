//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct CommentButtonClickedContext: Sendable {
        /// The id of the post
        public let postId: String

        public init(postId: String) {
            self.postId = postId
        }
    }
}
