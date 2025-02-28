//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Octopus

@Suite(.disabled("Disabled because we only need that they compile"))
class APITests {
    @Test func testOctopusSDKApi() async throws {
        _ = try OctopusSDK(apiKey: "API_KEY")
    }
}
