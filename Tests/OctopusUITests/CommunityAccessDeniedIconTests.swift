//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import UIKit
@testable import OctopusUI

/// The icon is one drawing cut in three layers, each tinted with a color of the theme: stacked, they only line up
/// when they share the same canvas.
struct CommunityAccessDeniedIconTests {
    @Test func theThreeLayersShareTheSameCanvas() {
        let sizes = [UIImage.Gen.noAccessIconPrimary, .Gen.noAccessIconOutline, .Gen.noAccessIconFill].map(\.size)

        #expect(sizes[0] != .zero)
        #expect(sizes[0] == sizes[1] && sizes[1] == sizes[2])
    }
}
