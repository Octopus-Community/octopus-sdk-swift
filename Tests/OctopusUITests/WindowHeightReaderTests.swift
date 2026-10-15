//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import OctopusUI

/// The window height reader reports the height of the window it is in, and follows it when it is resized.
@MainActor
struct WindowHeightReaderTests {

    @Test func readsTheHeightOfItsWindow() async throws {
        let height = HeightBox()
        let window = makeWindow(height: 844, reportingTo: height)
        defer { window.isHidden = true }

        try await waitUntil { height.value == 844 }
        #expect(height.value == 844)
    }

    @Test func followsItsWindowWhenItIsResized() async throws {
        let height = HeightBox()
        let window = makeWindow(height: 844, reportingTo: height)
        defer { window.isHidden = true }
        try await waitUntil { height.value == 844 }

        // UIKit resizes a window, when it is rotated for instance, by setting its frame: its bounds setter is not
        // called, so a reader observing the bounds alone would keep the old height.
        window.frame = CGRect(x: 0, y: 0, width: 844, height: 390)

        try await waitUntil { height.value == 390 }
        #expect(height.value == 390)
    }

    /// A visible window of the given height showing a view that reads its window height into `box`. The test host
    /// runs without scenes, so the window is attached to the screen directly.
    private func makeWindow(height: CGFloat, reportingTo box: HeightBox) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
        let binding = Binding(get: { box.value }, set: { box.value = $0 })
        window.rootViewController = UIHostingController(rootView: Color.clear.readWindowHeight(binding))
        window.makeKeyAndVisible()
        return window
    }
}

@MainActor
private final class HeightBox {
    var value: CGFloat = 0
}
