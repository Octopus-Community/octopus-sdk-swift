//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .postClicked
    public protocol PostClickedContext: Sendable {
        /// The id of the post
        var postId: String { get }
        /// The source of the click
        var source: PostClickedSource { get }
    }

    /// The source of the click on a post
    public enum PostClickedSource: Sendable {
        /// The post is displayed in the post feed
        case feed
        /// The post is displayed in the profile
        case profile
    }
}

extension SdkEvent.PostClickedContext: OctopusEvent.PostClickedContext {
    public var source: OctopusEvent.PostClickedSource { .init(from: coreSource) }
}

extension OctopusEvent.PostClickedSource {
    init(from source: SdkEvent.PostClickedContext.Source) {
        self = switch source {
        case .feed: .feed
        case .profile: .profile
        }
    }
}
