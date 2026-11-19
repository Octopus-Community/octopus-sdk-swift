//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The composer focus a detail screen owes once it opened from a comment button. When the screen opens on the most
/// recent end of its thread, the focus waits for the scroll that lands it there, so the keyboard does not rise over
/// a list still moving. A thread with nothing listed has no such scroll: the focus then happens once the landing ends.
struct ComposerFocusOnOpen {
    /// Whether the focus is still owed.
    private(set) var isPending: Bool
    private var waitsForLandingScroll: Bool

    /// What the screen does once the landing on the most recent end ended.
    struct LandingEnd: Equatable {
        let scrollsToBottom: Bool
        let focusesComposer: Bool
    }

    init(requested: Bool, opensOnMostRecentEnd: Bool) {
        isPending = requested
        waitsForLandingScroll = opensOnMostRecentEnd
    }

    /// The landing on the most recent end ended. A listed window is scrolled to its bottom and the focus waits for that
    /// scroll to end; an empty one has nothing to scroll to, so the focus happens now.
    mutating func landingEnded(hasListedResponses: Bool) -> LandingEnd {
        if hasListedResponses {
            return LandingEnd(scrollsToBottom: true, focusesComposer: false)
        }
        waitsForLandingScroll = false
        return LandingEnd(scrollsToBottom: false, focusesComposer: takeFocus())
    }

    /// A scroll to the bottom ended. Returns whether to focus the composer now.
    mutating func scrollToBottomEnded() -> Bool {
        waitsForLandingScroll = false
        return takeFocus()
    }

    /// The responses were listed. Returns whether to focus the composer now: not while a scroll is running or the
    /// landing scroll is still to come.
    mutating func responsesListed(scrollRunning: Bool) -> Bool {
        guard !scrollRunning, !waitsForLandingScroll else { return false }
        return takeFocus()
    }

    private mutating func takeFocus() -> Bool {
        guard isPending else { return false }
        isPending = false
        return true
    }
}
