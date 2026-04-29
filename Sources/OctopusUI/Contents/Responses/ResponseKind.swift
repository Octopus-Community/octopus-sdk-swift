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
