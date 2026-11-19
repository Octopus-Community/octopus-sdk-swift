//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// The horizontal pager of the fullscreen viewer, which hands the VoiceOver scrolls to the viewer.
final class FullscreenViewerPager: UIScrollView {
    var onAccessibilityScroll: ((UIAccessibilityScrollDirection) -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // A mostly vertical drag is the drag that closes: never page on it.
        if gestureRecognizer === panGestureRecognizer,
           !PagingRules.pagerPanShouldBegin(velocity: panGestureRecognizer.velocity(in: self)) {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        onAccessibilityScroll?(direction) ?? false
    }
}
