//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct ReplyCreatedContext: Sendable {
        public let replyId: String
        public let commentId: String
        public let textLength: Int

        init(from reply: Reply) {
            replyId = reply.uuid
            commentId = reply.parentId
            textLength = reply.text?.originalText.count ?? 0
        }
    }
}
