//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
class ArrayUtilsTests {
    @Test func testArrayShuffled() async throws {
        let original = Array(0...100)

        let shuffled1 = original.shuffled(seed: 42)
        let shuffled2 = original.shuffled(seed: 42)
        let shuffled3 = original.shuffled(seed: 1337)

        #expect(original != shuffled1)
        // ensure that the same seed produces the same result
        #expect(shuffled1 == shuffled2)
        #expect(shuffled1 != shuffled3)
    }
}
