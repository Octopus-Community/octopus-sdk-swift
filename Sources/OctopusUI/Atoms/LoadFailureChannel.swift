//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Where a load failure is reported: one error, one channel.
///
/// A screen whose content area is empty shows the failure in place of the list, with a retry. Once
/// content is displayed, taking it away to show an error would drop what the member is reading, so the
/// failure goes to a toast instead (Screen states spec).
///
/// Screens that fetch more than one thing — a group's metadata beside its feed, a profile beside its
/// posts — have to consult the *visible* content, not their own call: without it an outage shows twice,
/// once as the feed's screen state and once as a toast over it.
enum LoadFailureChannel {
    case screenState
    case toast

    init(hasVisibleContent: Bool) {
        self = hasVisibleContent ? .toast : .screenState
    }
}
