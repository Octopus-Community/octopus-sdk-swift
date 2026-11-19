//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import UIKit
@testable import OctopusUI

struct ContentIconsThemeTests {

    @Test func defaultTranslationIconIsTheSdkAssetTinted() {
        let content = OctopusTheme.Assets.Icons.Content()
        // The SDK asset is drawn in a 24×24 box, and tinted with the foreground color of the button.
        #expect(content.translation.size == CGSize(width: 24, height: 24))
        #expect(content.translation.renderingMode == .alwaysTemplate)
    }

    @Test func customTranslationIconIsUsedAndTinted() {
        let custom = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 12)).image { _ in }
        let content = OctopusTheme.Assets.Icons.Content(translation: custom)
        #expect(content.translation.size == CGSize(width: 10, height: 12))
        // Like every other icon of the theme, the host's image is tinted by the SDK.
        #expect(content.translation.renderingMode == .alwaysTemplate)
    }

    @Test func translationIconReachesTheThemeIcons() {
        let custom = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 12)).image { _ in }
        let icons = OctopusTheme.Assets.Icons(content: .init(translation: custom))
        #expect(icons.content.translation.size == CGSize(width: 10, height: 12))
    }
}
