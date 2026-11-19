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

    // `OctopusTheme.Colors().primary` defaults to this asset. Resolved through UIKit because
    // `UIColor(Color)` needs iOS 14 and the package still targets iOS 13.
    private func components(_ color: UIColor, _ style: UIUserInterfaceStyle) -> [CGFloat] {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        _ = resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue]
    }

    @Test func defaultPrimaryIsNotPureWhiteInDarkMode() {
        let dark = components(.Gen.Theme.Primary.main, .dark)
        // Pure white glares on the dark background: the default stays an off-white.
        #expect(dark.allSatisfy { $0 > 0.8 && $0 < 0.95 })
    }

    @Test func defaultDarkPrimaryDiffersFromTheUnselectedGray() {
        // Tabs and the toggle draw their selected state in primary and the unselected one in gray700.
        #expect(components(.Gen.Theme.Primary.main, .dark) != components(.Gen.Theme.gray700, .dark))
    }

    @Test func defaultPrimaryIsUnchangedInLightMode() {
        let light = components(.Gen.Theme.Primary.main, .light)
        #expect(light.allSatisfy { abs($0 - 0x14 / 255.0) < 0.01 })
    }
}
