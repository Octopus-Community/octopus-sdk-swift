//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Rules of the post composer's attachments: which entries it offers, whether the draft carries any
/// attachment, and how a block the user just added is revealed.
///
/// A post carries at most one image and at most one poll, independently of each other. Kept free of any
/// view or SDK state so the rules can be unit tested.
struct CreatePostAttachmentRules {
    let picturesEnabled: Bool
    let pollsEnabled: Bool
    let hasImage: Bool
    let hasPoll: Bool

    /// Picking a picture replaces the current one, so the entry stays offered while an image is attached.
    var canAddPicture: Bool { picturesEnabled }

    /// An attached image does not prevent adding the poll.
    var canAddPoll: Bool { pollsEnabled && !hasPoll }

    var showsActionBar: Bool { canAddPicture || canAddPoll }

    var hasNoAttachment: Bool { !hasImage && !hasPoll }

    /// Whether revealing a block the user just added aligns its top with the top of the visible area, which
    /// only happens when the block is taller than that area. Otherwise the reveal scrolls the minimum amount
    /// that shows the whole block. A block not measured yet (height 0) never aligns on top.
    static func revealAlignsTop(blockHeight: CGFloat, viewportHeight: CGFloat) -> Bool {
        blockHeight > viewportHeight
    }
}
