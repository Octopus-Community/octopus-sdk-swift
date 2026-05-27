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

    /// The post editor, optionally prefilled with content supplied by
    /// the host app. Use this entry point to let a user share an
    /// in-app object into the community.
    case createPost(CreatePostScreenInfo)

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

    /// Info needed to display the post editor as the initial screen.
    ///
    /// When `prefilledPost` is `nil`, the editor opens empty —
    /// equivalent to a regular in-SDK new-post flow. When non-nil, the
    /// editor opens prefilled with the provided text / image / topic /
    /// CTA.
    public struct CreatePostScreenInfo {
        /// The prefill payload, or `nil` for an empty editor.
        public let prefilledPost: OctopusPrefilledPost?

        /// Constructor
        /// - Parameter prefilledPost: The prefill payload, or `nil`
        ///   for an empty editor.
        public init(prefilledPost: OctopusPrefilledPost? = nil) {
            self.prefilledPost = prefilledPost
        }
    }
}
