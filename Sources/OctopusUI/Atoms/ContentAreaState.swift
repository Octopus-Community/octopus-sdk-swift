//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// What a content area shows: the list, the state that stands in for it, or the loader.
///
/// Every list in the SDK answers the same question — is there something to show, is a first load
/// still running, did it fail — and each screen used to answer it with its own ladder of `if`s. The
/// orders diverged, and that is where the defects came from: an empty state shown while the first
/// load was still running, and an empty state flashing between a failure and its retry.
enum ContentAreaState: Equatable {
    /// Nothing to show yet and the first load has not settled.
    case loader
    /// The first load settled on a failure, with nothing behind it to keep.
    case failure(ScreenStateFailure)
    /// The first load settled and there is genuinely nothing to show.
    case empty
    /// There is something to show.
    case content
}

/// Resolves what a content area shows.
///
/// - Parameters:
///   - itemCount: how many items are on screen. `nil` when the list has not been populated at all,
///     which the local store does before the server answers — an empty list is not the same as no
///     list, and neither means "nothing to show" until the first load settles.
///   - hasLoadedOnce: whether the first load settled, on content or on a failure. A retry resets it
///     so the loader — never the empty state — holds the screen while the new attempt runs.
///   - loadFailure: set only when the first load failed with nothing to keep. A failure over content
///     already displayed belongs to the toast and must not reach here.
func contentAreaState(itemCount: Int?, hasLoadedOnce: Bool,
                      loadFailure: ScreenStateFailure?) -> ContentAreaState {
    // The failure wins over the empty state: both describe an area with nothing in it, and only one
    // of them tells the member why and offers a way out.
    if let loadFailure { return .failure(loadFailure) }
    if (itemCount ?? 0) > 0 { return .content }
    return hasLoadedOnce ? .empty : .loader
}
