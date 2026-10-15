//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import SwiftUI
import UIKit
@testable import OctopusUI

struct OctopusThemeFontsTests {

    /// The default font of a style, a system font scaled for `sizeCategory`, written out like the public init does.
    ///
    /// Weight and design are explicit because a bare `Font.system(size:)` does not build the same font here: this
    /// target picks the iOS 16 overload, whose weight and design are nil, where the SDK picks the iOS 13 one.
    private func scaledSystemFont(_ baseSize: CGFloat, _ textStyle: UIFont.TextStyle,
                                  for sizeCategory: UIContentSizeCategory) -> Font {
        let traits = UITraitCollection(preferredContentSizeCategory: sizeCategory)
        let size = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: baseSize, compatibleWith: traits)
        return Font.system(size: size, weight: .regular, design: .default).weight(.regular)
    }

    // Guards the base sizes `resized(for:)` uses against the default values of the public init.
    @Test func everyDefaultFontIsRecognizedAsDefault() {
        #expect(OctopusTheme.Fonts().defaultStyles == Set(OctopusTheme.Fonts.Style.allCases))
    }

    // A host keeping a style at a fixed size with the very expression the defaults used to be built from: the same
    // system font, same size, same overload as the SDK. It must stay fixed whatever the text size at creation.
    @Test func aFixedSystemFontOfTheDefaultSizeIsNotTakenForTheDefault() {
        func fixed(_ baseSize: CGFloat, _ textStyle: UIFont.TextStyle) -> Font {
            let size = UIFontMetrics(forTextStyle: textStyle).scaledValue(for: baseSize)
            return Font.system(size: size, weight: .regular, design: .default)
        }
        let fonts = OctopusTheme.Fonts(
            title1: fixed(26, .title1), title2: fixed(22, .title2), body1: fixed(18, .body), body2: fixed(16, .body),
            caption1: fixed(14, .caption1), caption2: fixed(12, .caption2))

        #expect(fonts.defaultStyles.isEmpty)
        #expect(fonts.resized(for: .accessibilityExtraExtraExtraLarge).body2 == fonts.body2)
    }

    @Test func defaultFontsAreSizedForTheGivenTextSize() {
        let fonts = OctopusTheme.Fonts().resized(for: .accessibilityExtraExtraExtraLarge)

        #expect(fonts.title1 == scaledSystemFont(26, .title1, for: .accessibilityExtraExtraExtraLarge))
        #expect(fonts.title2 == scaledSystemFont(22, .title2, for: .accessibilityExtraExtraExtraLarge))
        #expect(fonts.body1 == scaledSystemFont(18, .body, for: .accessibilityExtraExtraExtraLarge))
        #expect(fonts.body2 == scaledSystemFont(16, .body, for: .accessibilityExtraExtraExtraLarge))
        #expect(fonts.caption1 == scaledSystemFont(14, .caption1, for: .accessibilityExtraExtraExtraLarge))
        #expect(fonts.caption2 == scaledSystemFont(12, .caption2, for: .accessibilityExtraExtraExtraLarge))
    }

    @Test func defaultFontsChangeWithTheTextSize() {
        let fonts = OctopusTheme.Fonts()
        #expect(fonts.resized(for: .extraSmall).body1 != fonts.resized(for: .accessibilityLarge).body1)
    }

    @Test func fontsGivenByTheHostAreKept() {
        let courier = Font.custom("Courier New", size: 26)
        let fixedSystem = Font.system(size: 20)
        let fonts = OctopusTheme.Fonts(title1: courier, body1: fixedSystem, navBarItem: .headline)
            .resized(for: .accessibilityExtraExtraExtraLarge)

        #expect(fonts.title1 == courier)
        #expect(fonts.body1 == fixedSystem)
        #expect(fonts.navBarItem == .headline)
        // The styles the host left on their default still follow the text size.
        #expect(fonts.title2 == scaledSystemFont(22, .title2, for: .accessibilityExtraExtraExtraLarge))
    }

    // A theme can be resized by each entry screen it goes through: the last text size wins.
    @Test func resizingAgainUsesTheLatestTextSize() {
        let fonts = OctopusTheme.Fonts()
        let resizedTwice = fonts.resized(for: .extraSmall).resized(for: .extraExtraLarge)

        #expect(resizedTwice.body1 == fonts.resized(for: .extraExtraLarge).body1)
        #expect(resizedTwice.defaultStyles == fonts.defaultStyles)
    }

    @Test func resizingATheme() {
        let theme = OctopusTheme(colors: .init(link: .purple))
        let resized = theme.resized(for: .accessibilityMedium)

        #expect(resized.fonts.body1 == scaledSystemFont(18, .body, for: .accessibilityMedium))
        #expect(resized.colors.link == theme.colors.link)
        #expect(resized.colors.primary == theme.colors.primary)
    }

    @Test(arguments: ContentSizeCategory.allCases)
    func contentSizeCategoryMapsLikeUIKit(_ sizeCategory: ContentSizeCategory) {
        guard #available(iOS 14.0, *) else { return }
        #expect(UIContentSizeCategory(compat: sizeCategory) == UIContentSizeCategory(sizeCategory))
    }
}
