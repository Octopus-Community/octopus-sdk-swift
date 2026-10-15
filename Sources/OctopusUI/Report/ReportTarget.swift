//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Identifies what is being reported when the report sheet is presented.
///
/// `blockableProfileId` is the profile the "Report sent" alert offers to block: the content's author or the
/// reported profile, set by the call site at tap time with the gate that already shows its Block menu entry
/// (`Author.canBeBlocked(currentUserId:)` for content, `DisplayableProfile.canBeBlocked` for a profile).
/// `nil` means no offer: the author cannot be blocked (moderator, the viewer) or cannot be identified
/// (anonymous or deleted author).
enum ReportTarget: Identifiable, Equatable {
    case content(contentId: String, blockableProfileId: String?)
    case profile(profileId: String, blockableProfileId: String?)

    var id: String {
        switch self {
        case .content(let contentId, _): return "content:\(contentId)"
        case .profile(let profileId, _): return "profile:\(profileId)"
        }
    }

    var blockableProfileId: String? {
        switch self {
        case .content(_, let blockableProfileId), .profile(_, let blockableProfileId): return blockableProfileId
        }
    }

    /// Reports a content, offering to block its author when `authorCanBeBlocked`.
    static func content(contentId: String, author: Author, authorCanBeBlocked: Bool) -> ReportTarget {
        .content(contentId: contentId, blockableProfileId: authorCanBeBlocked ? author.profileId : nil)
    }

    /// Reports a profile, offering to block it when `canBeBlocked`.
    static func profile(profileId: String, canBeBlocked: Bool) -> ReportTarget {
        .profile(profileId: profileId, blockableProfileId: canBeBlocked ? profileId : nil)
    }
}
