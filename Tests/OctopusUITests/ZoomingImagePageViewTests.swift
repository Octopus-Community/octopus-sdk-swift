//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit
import Testing
@testable import OctopusUI

/// One zoomable photo of the fullscreen viewer, hosted in a window. The photo is 400 × 200 in a 300 × 600 page: it
/// fits at 0.75 (300 × 150, centred vertically) and fills at 3.
@MainActor
struct ZoomingImagePageViewTests {
    private static let fit: CGFloat = 0.75
    private static let fill: CGFloat = 3

    @Test func imageStartsAtFitAndCentred() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }

        #expect(isClose(page.zoomScale, Self.fit))
        #expect(isClose(page.minimumZoomScale, Self.fit))
        #expect(page.bouncesZoom)
        let shownFrame = page.convert(page.imageView.frame, to: window)
        #expect(isClose(shownFrame, CGRect(x: 0, y: 225, width: 300, height: 150)))
    }

    @Test func cannotZoomOutBelowFit() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }

        page.zoomScale = Self.fit * 0.5

        #expect(isClose(page.zoomScale, Self.fit))
    }

    @Test func maxZoomIsFiveTimesFit() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }

        #expect(isClose(page.maximumZoomScale, Self.fit * 5))
        page.zoomScale = Self.fit * 8
        #expect(isClose(page.zoomScale, Self.fit * 5))
    }

    @Test func doubleTapTogglesFillAndFit() async throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        let haptics = HapticPlays()
        page.playHaptic = { haptics.plays += 1 }
        let doubleTap = page.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }
            .first { $0.numberOfTapsRequired == 2 }
        #expect(doubleTap != nil)

        page.toggleDoubleTapZoom(at: CGPoint(x: 150, y: 300))
        try await waitUntil { isClose(page.zoomScale, Self.fill) }
        #expect(haptics.plays == 0)
        // Centred on the tapped point, the centre of the photo: the 1200 × 600 photo is scrolled by half its overflow.
        #expect(isClose(page.contentOffset, CGPoint(x: 450, y: 0)))

        page.toggleDoubleTapZoom(at: CGPoint(x: 150, y: 300))
        try await waitUntil { isClose(page.zoomScale, Self.fit) }
        // Back to fit after a double tap: one haptic.
        #expect(haptics.plays == 1)
        try await waitUntil {
            isClose(page.convert(page.imageView.frame, to: window), CGRect(x: 0, y: 225, width: 300, height: 150))
        }
    }

    @Test func zoomChangeReportedOnce() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        let changes = ZoomChanges()
        page.onZoomChange = { changes.values.append($0) }

        page.zoomScale = Self.fit * 2
        page.zoomScale = Self.fit * 3
        #expect(changes.values == [true])

        page.zoomScale = Self.fit
        #expect(changes.values == [true, false])
    }

    @Test func zoomChangeFiresOnZoom() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        let changes = ZoomChanges()
        page.onZoomChange = { changes.values.append($0) }

        page.zoomScale = Self.fit * 2

        #expect(changes.values == [true])
    }

    @Test func keepsTheRelativeZoomWhenTheBoundsChange() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        page.zoomScale = Self.fit * 2

        // Rotated: the photo now fits at 1.5.
        page.frame = CGRect(x: 0, y: 0, width: 600, height: 300)
        page.layoutIfNeeded()

        #expect(isClose(page.minimumZoomScale, 1.5))
        #expect(isClose(page.maximumZoomScale, 7.5))
        #expect(isClose(page.zoomScale, 3))
    }

    @Test func keepsThePointUnderTheCentreWhenTheBoundsChange() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        // At 3 × fit the photo is shown at 900 × 450, 75 points below the top: this offset puts the photo point
        // (200, 100) under the centre of the page.
        page.zoomScale = Self.fit * 3
        page.contentOffset = CGPoint(x: 300, y: -75)
        #expect(isClose(pointUnderTheCentre(of: page), CGPoint(x: 200, y: 100)))

        page.frame = CGRect(x: 0, y: 0, width: 600, height: 300)
        page.layoutIfNeeded()

        #expect(isClose(page.zoomScale, 1.5 * 3))
        #expect(isClose(pointUnderTheCentre(of: page), CGPoint(x: 200, y: 100)))
    }

    @Test func refitsWhenTheBoundsChangeAtFit() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }

        page.frame = CGRect(x: 0, y: 0, width: 600, height: 300)
        page.layoutIfNeeded()

        #expect(isClose(page.zoomScale, 1.5))
        let shownFrame = page.convert(page.imageView.frame, to: window)
        #expect(isClose(shownFrame, CGRect(x: 0, y: 0, width: 600, height: 300)))
    }

    @Test func settingAnImageResetsTheZoom() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        page.zoomScale = Self.fit * 3
        let changes = ZoomChanges()
        page.onZoomChange = { changes.values.append($0) }

        // A square photo fits the width at 0.5.
        page.image = makeImage(size: CGSize(width: 600, height: 600))
        page.layoutIfNeeded()

        #expect(isClose(page.zoomScale, 0.5))
        #expect(changes.values == [false])
        let shownFrame = page.convert(page.imageView.frame, to: window)
        #expect(isClose(shownFrame, CGRect(x: 0, y: 150, width: 300, height: 300)))
    }

    @Test(arguments: [false, true])
    func resetZoomComesBackToFitWithoutHaptic(animated: Bool) async throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        let haptics = HapticPlays()
        page.playHaptic = { haptics.plays += 1 }
        page.zoomScale = Self.fit * 3

        page.resetZoom(animated: animated)

        try await waitUntil { isClose(page.zoomScale, Self.fit) }
        // Let an animated reset finish.
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(isClose(page.zoomScale, Self.fit))
        #expect(haptics.plays == 0)
    }

    @Test func voiceOverZoomsInAndOutBySteps() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        #expect(page.isAccessibilityElement)
        #expect(page.accessibilityTraits.contains(.image))
        let actions = try #require(page.accessibilityCustomActions)
        #expect(actions.count == 2)
        let zoomIn = try #require(actions.first)
        let zoomOut = try #require(actions.last)

        #expect(perform(zoomIn))
        #expect(isClose(page.zoomScale, Self.fit * 1.5))
        #expect(perform(zoomOut))
        #expect(isClose(page.zoomScale, Self.fit))
        // Already at fit: nothing to zoom out.
        #expect(!perform(zoomOut))

        for _ in 0..<10 { _ = perform(zoomIn) }
        #expect(isClose(page.zoomScale, Self.fit * 5))
    }

    @Test func voiceOverMovesAZoomedPhotoByAQuarterOfTheScreen() throws {
        let (window, page) = makePage()
        defer { window.isHidden = true }
        page.locale = Locale(identifier: "en")
        // At fit, nothing to move.
        #expect(page.accessibilityCustomActions?.map(\.name) == ["Zoom in", "Zoom out"])

        page.zoomScale = Self.fill
        page.contentOffset = CGPoint(x: 450, y: 0)
        let actions = try #require(page.accessibilityCustomActions)
        #expect(actions.map(\.name) == [
            "Zoom in", "Zoom out", "Move to the left", "Move to the right", "Move up", "Move down"
        ])
        let (left, right, up, down) = (actions[2], actions[3], actions[4], actions[5])

        // The 1200 × 600 photo in a 300 × 600 page: 75 points sideways, nothing to move up or down.
        #expect(perform(left))
        #expect(isClose(page.contentOffset, CGPoint(x: 375, y: 0)))
        #expect(perform(right))
        #expect(perform(right))
        #expect(isClose(page.contentOffset, CGPoint(x: 525, y: 0)))
        #expect(!perform(up))
        #expect(!perform(down))
        // Never past the edge of the photo.
        for _ in 0..<10 { _ = perform(right) }
        #expect(isClose(page.contentOffset, CGPoint(x: 900, y: 0)))
        #expect(!perform(right))

        // At 5 × fit, the 1500 × 750 photo is taller than the page: 150 points up or down.
        page.zoomScale = Self.fit * 5
        page.contentOffset = CGPoint(x: 600, y: 0)
        let moves = try #require(page.accessibilityCustomActions)
        #expect(perform(moves[5]))
        #expect(isClose(page.contentOffset, CGPoint(x: 600, y: 150)))
        #expect(perform(moves[4]))
        #expect(isClose(page.contentOffset, CGPoint(x: 600, y: 0)))

        // Back at fit, the move actions go away.
        page.zoomScale = Self.fit
        #expect(page.accessibilityCustomActions?.count == 2)
        #expect(!perform(left))
    }

    @Test func withoutAnImageZoomIsDisabled() throws {
        let (window, page) = makePage(image: nil)
        defer { window.isHidden = true }

        #expect(page.minimumZoomScale == page.maximumZoomScale)
        #expect(page.pinchGestureRecognizer?.isEnabled != true)

        page.image = makeImage(size: CGSize(width: 400, height: 200))
        page.layoutIfNeeded()

        #expect(isClose(page.maximumZoomScale, Self.fit * 5))
        #expect(page.pinchGestureRecognizer?.isEnabled == true)
    }

    // MARK: Helpers

    private func makePage(
        image: UIImage? = makeImage(size: CGSize(width: 400, height: 200))) -> (UIWindow, ZoomingImagePageView) {
        // The test host runs without scenes, so the window is attached to the screen directly.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let page = ZoomingImagePageView(frame: window.bounds)
        window.rootViewController?.view.addSubview(page)
        page.image = image
        page.layoutIfNeeded()
        return (window, page)
    }

    /// The point of the photo, in its own size, shown at the centre of the page.
    private func pointUnderTheCentre(of page: ZoomingImagePageView) -> CGPoint {
        page.convert(CGPoint(x: page.bounds.midX, y: page.bounds.midY), to: page.imageView)
    }

    private func perform(_ action: UIAccessibilityCustomAction) -> Bool {
        action.actionHandler?(action) ?? false
    }
}

@MainActor
private func makeImage(size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

private func isClose(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
    abs(lhs - rhs) < 0.001
}

private func isClose(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
    isClose(lhs.x, rhs.x) && isClose(lhs.y, rhs.y)
}

private func isClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    isClose(lhs.minX, rhs.minX) && isClose(lhs.minY, rhs.minY)
        && isClose(lhs.width, rhs.width) && isClose(lhs.height, rhs.height)
}

@MainActor
private final class ZoomChanges {
    var values: [Bool] = []
}

@MainActor
private final class HapticPlays {
    var plays = 0
}
