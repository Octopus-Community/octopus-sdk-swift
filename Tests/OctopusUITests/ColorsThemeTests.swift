//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import SwiftUI
@testable import OctopusUI

@Suite
@MainActor
class ColorsThemeTests {

    @Test func customLinkColorIsApplied() {
        #expect(OctopusTheme.Colors(link: .red).link == .red)
        #expect(OctopusTheme.Colors(link: .blue).link == .blue)
    }

    @Test func defaultLinkColorFallsBackToSdkDefault() {
        #expect(OctopusTheme.Colors().link == .Gen.Theme.link)
    }

    @Test func customLinkColorCoexistsWithPrimaryCustomization() {
        let colors = OctopusTheme.Colors(
            primarySet: .init(main: .red, lowContrast: .pink, highContrast: .orange),
            onPrimary: .white,
            link: .green)
        #expect(colors.link == .green)
        #expect(colors.primary == .red)
    }
}
