//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import SwiftUI
@testable import OctopusUI

struct OctopusThemeColorsTests {

    @Test func defaultBackgroundIsSystemBackground() {
        let colors = OctopusTheme.Colors()
        #expect(colors.background == Color(.systemBackground))
    }

    @Test func customBackgroundIsStored() {
        let colors = OctopusTheme.Colors(background: .red)
        #expect(colors.background == Color.red)
    }

    @Test func supplyingOnlyBackgroundLeavesOtherColorsAtDefault() {
        let custom = OctopusTheme.Colors(background: .red)
        let base = OctopusTheme.Colors()
        #expect(custom.primary == base.primary)
        #expect(custom.onPrimary == base.onPrimary)
        #expect(custom.link == base.link)
    }

    // Backward-compat: the initializer must still be callable without a background argument.
    @Test func initWithoutBackgroundStillCompilesAndDefaults() {
        let colors = OctopusTheme.Colors(primarySet: nil, onPrimary: nil, link: nil)
        #expect(colors.background == Color(.systemBackground))
    }
}
