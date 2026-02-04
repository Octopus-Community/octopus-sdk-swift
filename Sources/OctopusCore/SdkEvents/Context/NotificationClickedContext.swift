//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct NotificationClickedContext: Sendable {
        /// The id of the notification
        public let notificationId: String
        /// The target content id, if any
        public let contentId: String?

        public init(notificationId: String, action: NotifAction?) {
            self.notificationId = notificationId
            switch action {
            case let .open(path):
                switch path.last {
                case let .postDetail(postId, _, _):
                    contentId = postId
                case let .commentDetail(commentId, replyId):
                    contentId = replyId ?? commentId
                case .none:
                    contentId = nil
                }
            case .none:
                contentId = nil
            }
        }
    }
}
