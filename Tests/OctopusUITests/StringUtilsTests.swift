//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
class StringUtilsTests {
    @Test func testFormattedCount() async throws {
        #expect(String.formattedCount(9) == "9")
        #expect(String.formattedCount(99) == "99")
        #expect(String.formattedCount(999) == "999")
        #expect(String.formattedCount(9_999) == "9.9K")
        #expect(String.formattedCount(99_999) == "99K")
        #expect(String.formattedCount(999_999) == "999K")
        #expect(String.formattedCount(9_999_999) == "9.9M")
        #expect(String.formattedCount(99_999_999) == "99M")
        #expect(String.formattedCount(999_999_999) == "999M")
        #expect(String.formattedCount(9_999_999_999) == "9.9B")
        #expect(String.formattedCount(99_999_999_999) == "99B")
        #expect(String.formattedCount(999_999_999_999) == "999B")

        #expect(String.formattedCount(1) == "1")
        #expect(String.formattedCount(1000) == "1K")
        #expect(String.formattedCount(1001) == "1K")
        #expect(String.formattedCount(1250) == "1.2K")
        #expect(String.formattedCount(1251) == "1.2K")
        #expect(String.formattedCount(12551) == "12K")
        #expect(String.formattedCount(120551) == "120K")
        #expect(String.formattedCount(1205510) == "1.2M")
        #expect(String.formattedCount(12055100) == "12M")
        #expect(String.formattedCount(120551000) == "120M")
        #expect(String.formattedCount(1205510000) == "1.2B")
    }
}
