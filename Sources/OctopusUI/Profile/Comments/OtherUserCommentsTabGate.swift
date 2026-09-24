//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Whether **another member's** Comments tab should be shown. Three conditions, all required:
/// - `showCommentsOnOtherProfiles`: the per-community backend flag — the community opted in to
///   exposing a member's comments on their profile.
/// - `hasCommentsFeed`: the member's profile carries a non-empty `descCommentFeedId` (absent on an
///   older backend, or until the profile has loaded).
/// - `!commentsForbidden`: loading the feed was not refused server-side
///   (``ProfileCommentsListViewModel/isForbidden``) — the flag can be on while this particular feed
///   stays closed.
///
/// Shared by the two screens that can show another member — ``ProfileSummaryView`` (the native
/// profile) and ``ActivityView`` in other-user mode (the Unified Profile posts screen) — so the tab
/// depends only on the community flag and never on which route the tap took. The two paths have
/// already drifted apart once, the Activity one not reading the flag at all; keeping the rule in a
/// single pure function is what stops that happening again. Pure so it stays unit-testable
/// independently of either view model's Combine wiring.
///
/// The connected user's own screens never call this: their own comments are their own content, shown
/// unconditionally.
///
/// - Parameters:
///   - showCommentsOnOtherProfiles: the community config flag.
///   - hasCommentsFeed: whether a comments feed was resolved for that member.
///   - commentsForbidden: whether loading that feed was refused server-side.
func showsOtherUserCommentsTab(showCommentsOnOtherProfiles: Bool, hasCommentsFeed: Bool,
                               commentsForbidden: Bool) -> Bool {
    showCommentsOnOtherProfiles && hasCommentsFeed && !commentsForbidden
}
