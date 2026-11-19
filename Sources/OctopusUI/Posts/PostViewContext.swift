//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Describes where a `PostView` is rendered. Drives text truncation, tap behavior and whether the
/// group link is shown in the header.
enum PostViewContext {
    /// Rendered inside a feed (main feed, group feed, profile feed, etc.).
    ///
    /// - Parameters:
    ///   - onCardTap: called when the user taps the card surface or the group link.
    ///   - displayGroupName: whether the group link row is displayed in the header.
    case summary(onCardTap: () -> Void,
                 displayGroupName: Bool)
    /// Rendered as the post header of the detail screen.
    case detail
}
