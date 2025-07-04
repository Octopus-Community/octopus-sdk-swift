//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Testing
import CoreGraphics
@testable import OctopusCore

class ResizeTests {
    @Test func testResize() async throws {
        #expect(resize(CGSize(width: 100, height: 50)) == CGSize(width: 100, height: 50))
        #expect(resize(CGSize(width: 50, height: 100)) == CGSize(width: 50, height: 100))
        #expect(resize(CGSize(width: 8000, height: 800)) == CGSize(width: 1500, height: 150))
        #expect(resize(CGSize(width: 6000, height: 12000)) == CGSize(width: 750, height: 1500))
    }

    private func resize(_ originalSize: CGSize) -> CGSize {
        ImageResizer.resize(originalSize: originalSize)
    }
}
