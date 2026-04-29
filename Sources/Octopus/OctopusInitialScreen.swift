//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The initial screen to display when opening the Octopus UI.
public enum OctopusInitialScreen {
    /// The main feed screen with the feed selector
    case mainFeed
    /// A specific post detail screen (bridge mode)
    case post(PostScreenInfo)
    /// A specific group detail screen (bridge mode)
    case group(GroupScreenInfo)

    /// Info needed to display a post screen
    public struct PostScreenInfo {
        /// The id of the post to display
        public let postId: String

        /// Constructor
        /// - Parameter postId: The id of the post to display
        public init(postId: String) {
            self.postId = postId
        }
    }

    /// Info needed to display a group screen
    public struct GroupScreenInfo {
        /// The id of the group to display
        public let groupId: String

        /// Constructor
        /// - Parameter groupId: The id of the group to display
        public init(groupId: String) {
            self.groupId = groupId
        }
    }
}
