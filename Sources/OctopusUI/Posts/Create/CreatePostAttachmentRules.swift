//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// Rules of the post composer's attachments: which entries it offers, whether the draft carries any
/// attachment, and how a block the user just added is revealed.
///
/// A post carries up to `Validators.Post.maxImageCount` images and at most one poll, independently of each
/// other. Kept free of any view or SDK state so the rules can be unit tested.
struct CreatePostAttachmentRules {
    let picturesEnabled: Bool
    let pollsEnabled: Bool
    let imageCount: Int
    let hasPoll: Bool

    /// The entry stays offered once the post holds the maximum number of images: tapping it then explains the
    /// limit instead of opening the picker (see `pictureEntryShowsMaxAlert`).
    var canAddPicture: Bool { picturesEnabled }

    /// How many more images the post can take, which caps the selection of the next pick.
    var remainingPictureSlots: Int { max(Validators.Post.maxImageCount - imageCount, 0) }

    /// Whether the last thumbnail carries the « Add » pill that adds more images: only while the community allows
    /// pictures and the post holds at least one image and can still take another. Prefilled images can exist
    /// with pictures disabled, and the member must not add their own to them.
    var showsAddMorePill: Bool {
        picturesEnabled && imageCount >= 1 && imageCount < Validators.Post.maxImageCount
    }

    /// Whether the picture entry shows the maximum-reached alert instead of opening the picker.
    var pictureEntryShowsMaxAlert: Bool { imageCount >= Validators.Post.maxImageCount }

    /// Attached images do not prevent adding the poll.
    var canAddPoll: Bool { pollsEnabled && !hasPoll }

    var showsActionBar: Bool { canAddPicture || canAddPoll }

    var hasNoAttachment: Bool { imageCount == 0 && !hasPoll }

    /// Whether revealing a block the user just added aligns its top with the top of the visible area, which
    /// only happens when the block is taller than that area. Otherwise the reveal scrolls the minimum amount
    /// that shows the whole block. A block not measured yet (height 0) never aligns on top.
    static func revealAlignsTop(blockHeight: CGFloat, viewportHeight: CGFloat) -> Bool {
        blockHeight > viewportHeight
    }
}
