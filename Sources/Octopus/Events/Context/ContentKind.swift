//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// A kind of content
    #if hasAttribute(nonexhaustive)
    @nonexhaustive(warn)
    #endif
    public enum ContentKind {
        /// Content is a post
        case post
        /// Content is a comment
        case comment
        /// Content is a reply
        case reply
    }
}

extension OctopusEvent.ContentKind {
    init(from kind: SdkEvent.ContentKind) {
        self = switch kind {
        case .post: .post
        case .comment: .comment
        case .reply: .reply
        }
    }
}
