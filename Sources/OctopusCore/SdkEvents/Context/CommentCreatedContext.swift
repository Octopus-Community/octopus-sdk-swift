//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct CommentCreatedContext: Sendable {
        public let commentId: String
        public let postId: String
        public let textLength: Int

        init(from comment: Comment) {
            commentId = comment.uuid
            postId = comment.parentId
            textLength = comment.text?.originalText.count ?? 0
        }
    }
}
