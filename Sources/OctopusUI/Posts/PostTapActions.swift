//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// What a tap on a post image or on a post's group name does, given the community's post options.
///
/// Pure, so that every combination of options and context can be tested without rendering the post.
enum PostTapActions {
    /// The action that replaces the fullscreen viewer when a post image is tapped, or `nil` to keep the
    /// fullscreen viewer.
    ///
    /// The image opens the post, like the card does, only in a feed, when the community enables
    /// `imageTapOpensPost` and the card opens the post detail. When the card would only expand the text, and
    /// in the post detail, images keep opening fullscreen. The override sits above the media views, so their
    /// gestures and the viewer stay unchanged.
    ///
    /// - Parameters:
    ///   - context: where the post is rendered.
    ///   - options: the community's post options, `nil` when unknown.
    ///   - cardTapOpensDetail: whether tapping the card opens the post detail (rather than expanding its text).
    static func imageTapOverride(context: PostViewContext, options: ContentOptions.PostOptions?,
                                 cardTapOpensDetail: Bool) -> (() -> Void)? {
        guard case let .summary(onCardTap, _) = context, cardTapOpensDetail,
              options?.imageTapOpensPost == true else { return nil }
        return onCardTap
    }

    /// The action of a tap on the group name of a post, or `nil` when the name is not tappable.
    ///
    /// When the community enables `groupNameTapOpensGroup`, the name opens the group, in feeds and in the post
    /// detail. Otherwise it keeps the card action in feeds and does nothing in the post detail.
    ///
    /// - Parameters:
    ///   - context: where the post is rendered.
    ///   - options: the community's post options, `nil` when unknown.
    ///   - openGroup: opens the post's group, `nil` when the post has no group id.
    static func groupNameTapAction(context: PostViewContext, options: ContentOptions.PostOptions?,
                                   openGroup: (() -> Void)?) -> (() -> Void)? {
        if options?.groupNameTapOpensGroup == true, let openGroup {
            return openGroup
        }
        if case let .summary(onCardTap, _) = context {
            return onCardTap
        }
        return nil
    }
}
