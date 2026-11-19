//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// Kind of response
enum ResponseKind {
    case comment
    case reply
}

extension ResponseKind {
    /// The id a list gives a comment or reply row so a scroll request (`scrollToId`) can reach it. The row's
    /// own `.id` in `ResponseFeedItemView` cannot serve: it changes with the accessibility grouping to
    /// rebuild the cell, so a list and a view model that both build the anchor here never drift apart.
    func scrollAnchorId(for uuid: String) -> String {
        switch self {
        case .comment: "Comment-\(uuid)"
        case .reply: "Reply-\(uuid)"
        }
    }

    /// The id of the laid out part of a most recent end's window (see `MostRecentWindow.laidOutStart`): a scroll
    /// request reaches its first comment or reply through it. A lazy stack scrolls to its own children only, and the
    /// rows of the part are children of the part.
    var laidOutPartScrollAnchorId: String {
        switch self {
        case .comment: "Comment-laidOutPart"
        case .reply: "Reply-laidOutPart"
        }
    }

    var canReply: Bool {
        switch self {
        case .comment: true
        case .reply: false
        }
    }

    /// Localized string key for the "Delete" button label (more-menu entry, action sheet).
    var deleteButtonKey: LocalizedStringKey {
        switch self {
        case .comment: "Comment.Delete.Button"
        case .reply:   "Reply.Delete.Button"
        }
    }

    /// Localized string key for the delete-confirmation alert title, in the member's tone.
    func deleteConfirmationKey(tone: TextTone) -> LocalizedStringKey {
        switch self {
        case .comment: tone.key(formal: "Comment.Delete.Confirmation.Title.Formal",
                                informal: "Comment.Delete.Confirmation.Title.Informal")
        case .reply:   tone.key(formal: "Reply.Delete.Confirmation.Title.Formal",
                                informal: "Reply.Delete.Confirmation.Title.Informal")
        }
    }
}
