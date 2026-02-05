//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct PostClickedContext: Sendable {
        /// The id of the post
        public let postId: String
        /// The source of the click
        public let coreSource: Source

        public init(postId: String, coreSource: Source) {
            self.postId = postId
            self.coreSource = coreSource
        }

        public enum Source: Sendable {
            case feed
            case profile
        }
    }
}
