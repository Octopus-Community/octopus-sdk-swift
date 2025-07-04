//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusUI
import Octopus
import UIKit
import SwiftUI

@Suite(.disabled("Disabled because we only need that they compile"))
@MainActor
class APITests {
    @Test func testHomeScreen() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY")
        _ = OctopusHomeScreen(octopus: octopusSdk)
        _ = OctopusHomeScreen(octopus: octopusSdk, bottomSafeAreaInset: 5)
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarLeadingItem: .logo)
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarLeadingItem: .text(.init(text: "")))
        _ = OctopusHomeScreen(octopus: octopusSdk, navBarPrimaryColor: true)
        _ = OctopusHomeScreen(octopus: octopusSdk, notificationResponse: .constant(nil))
        _ = OctopusHomeScreen(octopus: octopusSdk, postId: "POST_ID")
    }

    @Test func testOctopusThemeApi() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY")
        // check that init with default params is available
        var theme = OctopusTheme()
        // check that it is customizable
        theme = OctopusTheme(
            colors: .init(primarySet: .init(main: .red, lowContrast: .blue, highContrast: .yellow),
                          onPrimary: .white),
            fonts: .init(
                title1: Font.custom("Courier New", size: 26),
                title2: Font.custom("Courier New", size: 20),
                body1: Font.custom("Courier New", size: 17),
                body2: Font.custom("Courier New", size: 14),
                caption1: Font.custom("Courier New", size: 12),
                caption2: Font.custom("Courier New", size: 10),
                navBarItem: Font.custom("Courier New", size: 17)
            ),
            assets: .init(logo: UIImage()))

        // check that it can be passed as environment
        _ = OctopusHomeScreen(octopus: octopusSdk)
            .environment(\.octopusTheme, theme)
    }
}
