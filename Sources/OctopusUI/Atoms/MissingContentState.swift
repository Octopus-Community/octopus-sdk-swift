//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// What a detail screen shows while it has no content to display.
///
/// A screen loses its content for reasons that call for different answers: the server said it is gone or
/// out of reach, a fetch failed and the member can retry, or a fetch is still running. The logout purge
/// empties the cache of every screen on display, so all three happen to a screen that was showing its
/// content a moment before: only the first may read as "not available".
enum MissingContentState: Equatable {
    /// No answer yet: the first load, or the check made once the content vanished from the cache.
    case loader
    /// The load failed without an answer from the server about the content itself.
    case failure(ScreenStateFailure)
    /// The server answered that the content is gone, or the member may not see it.
    case notAvailable
}

/// Resolves what a detail screen shows while it has no content, in the order the post screen uses.
///
/// - Parameters:
///   - notAvailable: set only once the server answered that the content is gone or out of reach.
///   - loadFailure: set when a load failed with nothing on screen to keep.
func missingContentState(notAvailable: Bool, loadFailure: ScreenStateFailure?) -> MissingContentState {
    // The server's answer wins over a failure that came before it.
    if notAvailable { return .notAvailable }
    if let loadFailure { return .failure(loadFailure) }
    return .loader
}
