//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

/// Tests for the pure scroll-to-top decision used by the feed view models after the post composer is
/// dismissed. The view models themselves require a full OctopusSDK instance, so the decision is tested
/// here as a pure helper (mirroring the pattern used in PostListViewModelTests / CreatePostViewModelTests).
struct FeedComposerScrollPolicyTests {

    private let composer: MainFlowScreen = .createPost(withPoll: false, defaultTopicId: nil)

    /// Successful creation: the composer is dismissed back to the feed root and a post was created.
    /// The feed should scroll to top so the user sees their new post (existing, intentional behavior).
    @Test func scrollsWhenComposerDismissedToRootAfterCreatingPost() {
        #expect(FeedComposerScrollPolicy.shouldScrollToTop(
            previousLast: composer, current: [], didCreatePost: true) == true)
    }

    /// The bug: the composer is dismissed back to the feed root via Back / swipe-down WITHOUT creating
    /// a post. The feed must keep its scroll position — no scroll to top.
    @Test func doesNotScrollWhenComposerCancelled() {
        #expect(FeedComposerScrollPolicy.shouldScrollToTop(
            previousLast: composer, current: [], didCreatePost: false) == false)
    }

    /// The composer was dismissed but not back to the feed root (e.g. it sat above a pushed group
    /// detail). This view model is not the active feed root, so it must not scroll.
    @Test func doesNotScrollWhenNotReturningToRoot() {
        #expect(FeedComposerScrollPolicy.shouldScrollToTop(
            previousLast: composer, current: [.groupDetail(groupId: "GROUP_ID")], didCreatePost: true) == false)
    }

    /// A different screen (not the composer) was dismissed back to root — unrelated to post creation.
    @Test func doesNotScrollWhenPreviousScreenIsNotComposer() {
        #expect(FeedComposerScrollPolicy.shouldScrollToTop(
            previousLast: .currentUserProfile, current: [], didCreatePost: true) == false)
    }

    /// No previous screen (initial state) — nothing to react to.
    @Test func doesNotScrollWhenNoPreviousScreen() {
        #expect(FeedComposerScrollPolicy.shouldScrollToTop(
            previousLast: nil, current: [], didCreatePost: true) == false)
    }
}
