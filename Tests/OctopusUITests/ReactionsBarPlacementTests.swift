//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
import UIKit
@testable import OctopusUI

/// The reactions bar is centered on, and fits in, the window's safe area rather than the whole window: on a device
/// whose camera sits on a side edge, the safe area is not centered in the window.
@MainActor
struct ReactionsBarPlacementTests {

    @Test func safeAreaLeavesOutTheInsetsOfEachEdge() {
        let safeArea = windowSafeArea(
            bounds: CGRect(x: 0, y: 0, width: 466, height: 678),
            insets: UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 84))

        #expect(safeArea == CGRect(x: 0, y: 20, width: 382, height: 638))
    }

    @Test func barIsCenteredOnTheSafeAreaWhenTheInsetIsOnOneSide() {
        let rectWidth: CGFloat = 3000
        let safeArea = CGRect(x: 0, y: 0, width: 382, height: 678)
        let buttonMidX: CGFloat = 100

        let x = overlayXPosition(centeredOn: safeArea, anchorMidX: buttonMidX, overlayRectWidth: rectWidth)

        // The rect is centered on the button, so the bar lands on screen at buttonMidX + (x - rectWidth / 2).
        #expect(buttonMidX + (x - rectWidth / 2) == 191)
    }

    @Test func barIsCenteredOnTheWindowWhenTheInsetsAreSymmetric() {
        let rectWidth: CGFloat = 3000
        let safeArea = CGRect(x: 62, y: 0, width: 750, height: 390)
        let buttonMidX: CGFloat = 200

        let x = overlayXPosition(centeredOn: safeArea, anchorMidX: buttonMidX, overlayRectWidth: rectWidth)

        #expect(buttonMidX + (x - rectWidth / 2) == 437)
    }

    @Test func barStaysOnTheButtonWhileTheSafeAreaIsUnknown() {
        let x = overlayXPosition(centeredOn: .zero, anchorMidX: 100, overlayRectWidth: 3000)

        #expect(x == 1500)
    }

    @Test func emojisAreSizedToTheSafeAreaWidth() throws {
        let narrower = try #require(PopoverReactionsBar.maxEmojiSize(availableWidth: 382, reactionCount: 6))
        let wider = try #require(PopoverReactionsBar.maxEmojiSize(availableWidth: 466, reactionCount: 6))

        // 382 - 2 * 32 margins - 2 * 12 padding - 5 * 4 spacing = 274, over 6 emojis.
        #expect(narrower == CGFloat(274) / 6)
        #expect(narrower < wider)
    }

    @Test func emojisAreNotCappedWhileTheWidthIsUnknown() {
        #expect(PopoverReactionsBar.maxEmojiSize(availableWidth: 0, reactionCount: 6) == nil)
    }

    @Test func readsTheSafeAreaOfItsWindow() async throws {
        let safeArea = SafeAreaBox()
        let window = makeWindow(width: 390, height: 844, reportingTo: safeArea)
        defer { window.isHidden = true }

        try await waitUntil { safeArea.value == windowSafeArea(bounds: window.bounds, insets: window.safeAreaInsets) }
        #expect(safeArea.value.width > 0)
    }

    @Test func followsItsWindowWhenItIsResized() async throws {
        let safeArea = SafeAreaBox()
        let window = makeWindow(width: 390, height: 844, reportingTo: safeArea)
        defer { window.isHidden = true }
        try await waitUntil { safeArea.value.width > 0 }

        window.frame = CGRect(x: 0, y: 0, width: 844, height: 390)

        try await waitUntil { safeArea.value == windowSafeArea(bounds: window.bounds, insets: window.safeAreaInsets) }
        #expect(safeArea.value.maxX <= 844)
        #expect(safeArea.value.width > 390)
    }

    /// A visible window of the given size showing a view that reads its window safe area into `box`. The test host
    /// runs without scenes, so the window is attached to the screen directly.
    private func makeWindow(width: CGFloat, height: CGFloat, reportingTo box: SafeAreaBox) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        let binding = Binding(get: { box.value }, set: { box.value = $0 })
        window.rootViewController = UIHostingController(rootView: Color.clear.readWindowSafeArea(binding))
        window.makeKeyAndVisible()
        return window
    }
}

@MainActor
private final class SafeAreaBox {
    var value: CGRect = .zero
}
