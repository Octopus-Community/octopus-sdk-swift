//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

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

    /// Localized string key for the delete-confirmation alert title.
    var deleteConfirmationKey: LocalizedStringKey {
        switch self {
        case .comment: "Comment.Delete.Confirmation.Title"
        case .reply:   "Reply.Delete.Confirmation.Title"
        }
    }
}
