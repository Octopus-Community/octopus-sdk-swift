//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
class EllipsizableTextTests {
    @Test func testEllipsizeOnChars() async throws {
        let text = "12345\n6\n\n\n78\n\n9"
        #expect(EllipsizableText(text: text, maxLength: 5, maxLines: Int.max)?.fullText == text)
        #expect(EllipsizableText(text: text, maxLength: 5, maxLines: Int.max)?.ellipsizedText == "12345")
        #expect(EllipsizableText(text: text, maxLength: 11, maxLines: Int.max)?.ellipsizedText == "12345\n6\n\n\n7")
    }

    @Test func testEllipsizeOnLines() async throws {
        let text = "12345\n6\n\n\n78\n\n9"
        #expect(EllipsizableText(text: text, maxLength: Int.max, maxLines: 2)?.fullText == text)
        #expect(EllipsizableText(text: text, maxLength: Int.max, maxLines: 2)?.ellipsizedText == "12345\n6")
        #expect(EllipsizableText(text: text, maxLength: Int.max, maxLines: 6)?.ellipsizedText == "12345\n6\n\n\n78\n")
    }

    @Test func testEllipsizeOnCharsAndLines() async throws {
        let text = "12345\n6\n\n\n78\n\n9"
        #expect(EllipsizableText(text: text, maxLength: 11, maxLines: 6)?.fullText == text)
        #expect(EllipsizableText(text: text, maxLength: 11, maxLines: 6)?.ellipsizedText == "12345\n6\n\n\n7")
    }
}

