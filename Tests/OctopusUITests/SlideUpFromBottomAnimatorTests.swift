//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import UIKit
@testable import OctopusUI

@Suite
@MainActor
class SlideUpFromBottomAnimatorTests {

    @Test func presentAnimator_exposesPresentDirection() {
        let animator = SlideUpFromBottomAnimator(direction: .present)
        #expect(animator.direction == .present)
    }

    @Test func dismissAnimator_exposesDismissDirection() {
        let animator = SlideUpFromBottomAnimator(direction: .dismiss)
        #expect(animator.direction == .dismiss)
    }

    @Test func transitionDuration_isConstant_regardlessOfDirection() {
        #expect(SlideUpFromBottomAnimator(direction: .present).transitionDuration(using: nil) == 0.5)
        #expect(SlideUpFromBottomAnimator(direction: .dismiss).transitionDuration(using: nil) == 0.5)
    }

    @Test func transitionDuration_ignoresProvidedContext() {
        // The animator uses a fixed duration and must not depend on the (optional) context.
        let animator = SlideUpFromBottomAnimator(direction: .present)
        #expect(animator.transitionDuration(using: nil) == 0.5)
    }
}
