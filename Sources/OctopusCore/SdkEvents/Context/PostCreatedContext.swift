//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct PostCreatedContext: Sendable {
        public let postId: String
        public let coreContent: Content
        public let topicId: String
        public let textLength: Int

        init(from post: Post) {
            var postContent = Content()
            if !post.text.originalText.isEmpty {
                postContent.insert(.text)
            }
            if post.medias.contains(where: { $0.kind == .image }) {
                postContent.insert(.image)
            }
            if post.poll != nil {
                postContent.insert(.poll)
            }
            postId = post.uuid
            coreContent = postContent
            topicId = post.parentId
            textLength = post.text.originalText.count
        }
    }
}

extension SdkEvent.PostCreatedContext {
    public struct Content: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let text = Content(rawValue: 1 << 0)
        public static let image = Content(rawValue: 1 << 1)
        public static let poll = Content(rawValue: 1 << 2)
    }
}
