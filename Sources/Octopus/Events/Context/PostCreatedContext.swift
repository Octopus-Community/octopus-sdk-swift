//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .postCreated
    public protocol PostCreatedContext: Sendable {
        /// The id of the post.
        var postId: String { get }
        /// Content of the post. This is an OptionSet containing the content info.
        var content: PostContent { get }
        /// The id of the topic to which the post has been linked
        var topicId: String { get }
        /// The length of the text of this post
        var textLength: Int { get }
    }

    /// A content of a post.
    /// This is an option set so you can use
    /// ```
    /// content.contains(.text)
    /// ```
    public struct PostContent: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// This post has a text
        public static let text = PostContent(rawValue: 1 << 0)
        /// This post has an image
        public static let image = PostContent(rawValue: 1 << 1)
        /// This post has a poll
        public static let poll = PostContent(rawValue: 1 << 2)
    }
}

extension SdkEvent.PostCreatedContext: OctopusEvent.PostCreatedContext {
    public var content: OctopusEvent.PostContent {
        .init(rawValue: coreContent.rawValue)
    }
}
