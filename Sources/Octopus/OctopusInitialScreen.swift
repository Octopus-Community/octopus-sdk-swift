//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The initial screen to display when opening the Octopus UI.
#if hasAttribute(nonexhaustive)
@nonexhaustive(warn)
#endif
public enum OctopusInitialScreen {
    /// The main feed screen with the feed selector
    case mainFeed
    /// A specific post detail screen (bridge mode)
    case post(PostScreenInfo)
    /// A specific group detail screen (bridge mode)
    case group(GroupScreenInfo)

    /// The posts-only screen listing a member's Octopus posts (Unified Profile).
    ///
    /// Open it from your own profile screen to surface a member's Octopus posts. Identify the member
    /// either by your app's own id (``ActivityScreenInfo/init(clientUserId:)``) or by their Octopus
    /// profile id (``ActivityScreenInfo/init(profileId:)``). A client user id is resolved to its
    /// Octopus profile through the `GetPublicProfile` client-user-id lookup (requires the community to
    /// expose client user ids, `CommunityConfig.exposeClientUserId`); if it cannot be resolved
    /// (unknown/stale mapping, or the community does not expose client user ids) the screen shows its
    /// empty state rather than falling back to any other member. An Octopus profile id needs no such
    /// lookup — the screen opens directly. For another member the screen lists that member's posts
    /// under a "{author}'s Posts" title, with no profile header — plus a Comments tab, under a
    /// "{author}'s Activity" title, when the community exposes other members' comments; in the edge
    /// case where the id resolves to the connected user's own, it opens their tabbed "Activity"
    /// screen instead.
    case activity(ActivityScreenInfo)

    /// The post editor, optionally prefilled with content supplied by
    /// the host app. Use this entry point to let a user share an
    /// in-app object into the community.
    case createPost(CreatePostScreenInfo)

    /// The profile of a member: the connected user's own (``ProfileScreenInfo/currentUser``), or another
    /// member's, identified by your app's own id (``ProfileScreenInfo/init(clientUserId:)``) or by their
    /// Octopus profile id (``ProfileScreenInfo/init(profileId:)``).
    ///
    /// A client user id is resolved to its Octopus profile through the client-user-id lookup (requires the
    /// community to expose client user ids). When it cannot be resolved (unknown id, the community does not
    /// expose client user ids, or a network failure), the screen shows an error state: it never falls back to
    /// the connected user's own profile.
    ///
    /// Like every initial screen, it is replaced by the access denied screen when the user cannot access the
    /// community.
    case profile(ProfileScreenInfo)

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

    /// Info needed to display the posts-only screen of a member (Unified Profile). Construct it with
    /// either the host app's own client user id (``init(clientUserId:)``) or the member's Octopus
    /// profile id (``init(profileId:)``).
    public struct ActivityScreenInfo {
        /// How the member whose posts to display is identified.
        package enum Source {
            /// The host app's own id for the member, resolved to an Octopus profile through the
            /// `GetPublicProfile` client-user-id lookup.
            case clientUserId(String)
            /// The member's Octopus profile id — already resolved, needs no lookup.
            case profileId(String)
        }

        /// How the member whose posts to display is identified (client user id or Octopus profile id).
        package let source: Source

        /// Constructor from the host app's own id for the member.
        ///
        /// The id is resolved to an Octopus profile through the `GetPublicProfile` client-user-id
        /// lookup (requires the community to expose client user ids).
        /// - Parameter clientUserId: The host app's own id for the member whose posts to display.
        public init(clientUserId: String) {
            self.source = .clientUserId(clientUserId)
        }

        /// Constructor from the member's Octopus profile id.
        ///
        /// Use this when you already hold the member's Octopus profile id (e.g. one surfaced by a
        /// profile tap): the screen opens directly, with no client-user-id lookup.
        /// - Parameter profileId: The Octopus profile id of the member whose posts to display.
        public init(profileId: String) {
            self.source = .profileId(profileId)
        }
    }

    /// Info needed to display the profile of a member. Construct it with ``currentUser`` for the connected
    /// user's own profile, with the host app's own client user id (``init(clientUserId:)``) or with the
    /// member's Octopus profile id (``init(profileId:)``).
    public struct ProfileScreenInfo {
        /// Whose profile to display.
        package enum Source: Equatable {
            /// The connected user's own profile.
            case currentUser
            /// The host app's own id for the member, resolved to an Octopus profile through the
            /// client-user-id lookup.
            case clientUserId(String)
            /// The member's Octopus profile id — already resolved, needs no lookup.
            case profileId(String)
        }

        /// Whose profile to display.
        package let source: Source

        /// The connected user's own profile.
        public static var currentUser: ProfileScreenInfo { .init(source: .currentUser) }

        /// Constructor from the host app's own id for the member.
        ///
        /// The id is resolved to an Octopus profile through the client-user-id lookup (requires the
        /// community to expose client user ids).
        /// - Parameter clientUserId: The host app's own id for the member whose profile to display.
        public init(clientUserId: String) {
            self.source = .clientUserId(clientUserId)
        }

        /// Constructor from the member's Octopus profile id.
        ///
        /// Use this when you already hold the member's Octopus profile id: the screen opens directly, with no
        /// client-user-id lookup.
        /// - Parameter profileId: The Octopus profile id of the member whose profile to display.
        public init(profileId: String) {
            self.source = .profileId(profileId)
        }

        private init(source: Source) {
            self.source = source
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
