//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import UIKit
import Testing
@testable import OctopusUI

@Suite
struct ContentWidthConstraintTests {
    @Test func testMaxContentWidthOnIPhone() {
        #expect(OctopusContentLayout.maxContentWidth(for: .phone) == 570)
    }

    @Test func testMaxContentWidthOnIPad() {
        #expect(OctopusContentLayout.maxContentWidth(for: .pad) == 1106)
    }

    @Test func testMaxContentWidthFallsBackToPhoneValueForOtherIdioms() {
        // Any non-pad idiom (unspecified, tv, carPlay, mac…) uses the iPhone cap.
        #expect(OctopusContentLayout.maxContentWidth(for: .unspecified) == 570)
        #expect(OctopusContentLayout.maxContentWidth(for: .tv) == 570)
    }
}
