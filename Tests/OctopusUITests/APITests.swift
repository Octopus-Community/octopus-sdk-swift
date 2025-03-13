//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusUI
import Octopus
import UIKit

@Suite(.disabled("Disabled because we only need that they compile"))
@MainActor
class APITests {
    @Test func testHomeScreen() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY")
        _ = OctopusHomeScreen(octopus: octopusSdk)
    }

    @Test func testOctopusThemeApi() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY")
        // check that init with default params is available
        var theme = OctopusTheme()
        // check that it is customizable
        theme = OctopusTheme(
            colors: .init(primarySet: .init(main: .red, lowContrast: .blue, highContrast: .yellow),
                          onPrimary: .white),
            fonts: .init(),
            assets: .init(logo: UIImage()))

        // check that it can be passed as environment
        _ = OctopusHomeScreen(octopus: octopusSdk)
            .environment(\.octopusTheme, theme)
    }
}
