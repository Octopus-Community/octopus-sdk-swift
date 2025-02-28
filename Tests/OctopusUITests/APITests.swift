//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusUI

@Suite(.disabled("Disabled because we only need that they compile"))
class APITests {
    @Test func testHomeScreen() async throws {
        let octopus = try OctopusSDK(apiKey: "API_KEY")
        _ = OctopusHomeScreen(octopus: octopus)
    }

    @Test func testOctopusThemeApi() async throws {
        let octopusSdk = try OctopusSDK(apiKey: "API_KEY")
        // check that init with default params is available
        var theme = OctopusTheme()
        // check that it is customizable
        theme = OctopusTheme(
            colors: .init(accent: .red, textOnAccent: .white),
            fonts: .init(),
            assets: .init(logo: UIImage()))

        // check that it can be passed as environment
        _ = OctopusHomeScreen(octopus: octopus)
            .environment(\.octopusTheme, theme)
    }
}
