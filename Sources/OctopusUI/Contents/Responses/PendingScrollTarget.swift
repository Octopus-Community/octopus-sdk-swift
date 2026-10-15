//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The comment or reply a detail screen opened on, until the screen has scrolled to it.
///
/// The scroll waits for the load until the target to settle, even when the target is already listed: that
/// load can still replace the listed items (a feed filled from a stale local page is refreshed from the
/// server), and a scroll made before would be undone as the list changes under it.
struct PendingScrollTarget: Equatable {
    /// The target's id, until it is taken.
    private(set) var id: String?
    /// Whether the load until the target is running.
    private(set) var isLoading = false

    init(id: String?) {
        self.id = id
    }

    mutating func loadStarted() {
        isLoading = id != nil
    }

    mutating func loadSettled() {
        isLoading = false
    }

    /// Returns the target's id once the screen can scroll to it — its load settled and it is listed — and
    /// forgets it, so the screen scrolls to it once.
    mutating func takeIfListed(_ listedIds: [String]) -> String? {
        guard !isLoading, let id, listedIds.contains(id) else { return nil }
        self.id = nil
        return id
    }
}
