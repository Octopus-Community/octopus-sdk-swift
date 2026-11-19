//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// What the server answered about content that vanished from the cache. The logout purge empties the cache of
/// what the previous session saw, so a vanished post or group may still exist: only the server can tell, and only
/// an answer that says so makes the screen show it as gone.
enum VanishedContentCheck: Equatable {
    /// The server still has it: the next session fetches it back into the cache.
    case stillAvailable
    /// The server says it does not exist any more.
    case gone
    /// The server could not be asked. The screen keeps what it shows and reports the failure.
    case unanswered(ScreenStateFailure)

    /// The answer to fetching the content itself, where a missing content is a `notFound` error.
    init(fetchError: ServerCallError?) {
        guard let fetchError else {
            self = .stillAvailable
            return
        }
        if case .serverError(.notFound) = fetchError {
            self = .gone
        } else {
            self = .unanswered(ScreenStateFailure(fetchError))
        }
    }

    /// Whether a detail screen fetches its content again when the displayed content is cleared (a logout, the
    /// reopening of a closed community). Only a screen left on its failure state with nothing shown does, as its
    /// retry would: its content vanished while the server could not be asked, as when a closure blocked every call.
    /// Otherwise the check the emptied cache started is running or answered, and a second fetch would race it.
    static func asksAgainOnClearedContent(contentShown: Bool, loadFailure: ScreenStateFailure?) -> Bool {
        !contentShown && loadFailure != nil
    }

    /// The answer to fetching a list that should contain the content, where a missing content is a successful
    /// fetch without it.
    init(fetchedIds: Result<[String], ServerCallError>, id: String) {
        switch fetchedIds {
        case let .success(ids):
            self = ids.contains(id) ? .stillAvailable : .gone
        case let .failure(error):
            self = .unanswered(ScreenStateFailure(error))
        }
    }
}

extension InternalSdkEvent {
    /// Whether the cache was emptied of what the previous session saw, or what is on screen was loaded with no session:
    /// every list on screen loads its content again, since its rows may have been removed or still carry the
    /// reactions and permissions of another session.
    var clearedDisplayedContent: Bool {
        if case .userContentCleared = self { return true }
        return false
    }
}
