//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Describes where a `ResponseView` is rendered. Drives card tap behaviour; other differences
/// (reply button visibility, see-replies row) are driven by the data's `kind` not by the context.
enum ResponseViewContext {
    /// In a list — post detail's comment list, or comment detail's reply list.
    /// `onCardTap` is optional: pass `nil` to skip the "tap anywhere on the card" shortcut
    /// (used for comments in `PostDetailView`, where only the avatar, "See N replies" row,
    /// and action-bar buttons should be tappable). Pass a closure to enable it (used for the
    /// featured comment in `PostSummaryView`, where tapping the card opens the parent post).
    case summary(onCardTap: (() -> Void)?)
    /// As the header of the comment detail screen.
    case detail
}
