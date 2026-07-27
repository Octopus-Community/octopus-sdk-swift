//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Decides whether a feed should scroll back to its top after the post composer (`.createPost`) is
/// dismissed.
///
/// The feed scrolls to top **only** when the composer is dismissed back to the feed root
/// (`current` is empty) **and** a post was actually created during that composer session — so the user
/// lands on their freshly created post. Cancelling the composer (Back button or swipe-down of the
/// modal) creates no post, so the feed keeps its previous scroll position.
enum FeedComposerScrollPolicy {
    static func shouldScrollToTop(previousLast: MainFlowScreen?, current: [MainFlowScreen],
                                  didCreatePost: Bool) -> Bool {
        guard case .createPost = previousLast, current.isEmpty else { return false }
        return didCreatePost
    }
}
