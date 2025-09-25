//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
class StringUtilsTests {
    @Test func testFormattedCount() async throws {
        #expect(String.formattedCount(1) == "1")
        #expect(String.formattedCount(999) == "999")
        #expect(String.formattedCount(1000) == "1K")
        #expect(String.formattedCount(1001) == "1K")
        #expect(String.formattedCount(1250) == "1.2K")
        #expect(String.formattedCount(1251) == "1.3K")
        #expect(String.formattedCount(12551) == "13K")
        #expect(String.formattedCount(120551) == "121K")
        #expect(String.formattedCount(1205510) == "1.2M")
        #expect(String.formattedCount(12055100) == "12M")
        #expect(String.formattedCount(120551000) == "121M")
        #expect(String.formattedCount(1205510000) == "1.2B")
    }
}
