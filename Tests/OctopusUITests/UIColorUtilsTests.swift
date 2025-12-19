//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import UIKit
@testable import OctopusUI

@Suite
class UIColorUtilsTests {
    @Test func testInitFromHex() async throws {
        #expect(UIColor(hex: "#1234ef") == UIColor(hex: "1234ef"))
        #expect(UIColor(hex: "#ff1234ef") == UIColor(hex: "1234ef"))
        #expect(UIColor(hex: "ff1234ef") == UIColor(hex: "1234ef"))

        #expect(UIColor(hex: "#ffffffff") == UIColor(red: 1, green: 1, blue: 1, alpha: 1))
        #expect(UIColor(hex: "#00000000") == UIColor(red: 0, green: 0, blue: 0, alpha: 0))
        #expect(UIColor(hex: "#12345678") == UIColor(red: 52/255, green: 86/255, blue: 120/255, alpha: 18/255))
        #expect(UIColor(hex: "#fedcba98") == UIColor(red: 220/255, green: 186/255, blue: 152/255, alpha: 254/255))

        #expect(UIColor(hex: "#g0000000") == nil)
        #expect(UIColor(hex: "12345") == nil)
        #expect(UIColor(hex: "123456789") == nil)
    }
}
