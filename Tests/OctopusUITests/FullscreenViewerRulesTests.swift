//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit
import Testing
@testable import OctopusUI

@Suite
struct FullscreenViewerRulesTests {
    private let phone = CGSize(width: 400, height: 800)

    @Test func fitAndFillOfAPortraitPhotoOnAPhone() {
        let image = CGSize(width: 1000, height: 2000)
        #expect(abs(ZoomRules.fitScale(imageSize: image, bounds: phone) - 0.4) < 0.0001)
        #expect(abs(ZoomRules.fillScale(imageSize: image, bounds: phone) - 0.4) < 0.0001)
    }

    @Test func fitAndFillOfALandscapePhoto() {
        let image = CGSize(width: 2000, height: 1000)
        #expect(abs(ZoomRules.fitScale(imageSize: image, bounds: phone) - 0.2) < 0.0001)
        #expect(abs(ZoomRules.fillScale(imageSize: image, bounds: phone) - 0.8) < 0.0001)
    }

    @Test func maxIsFiveTimesFit() {
        #expect(ZoomRules.maxScale(fit: 0.2) == 1)
        #expect(ZoomRules.maxScale(fit: 1) == 5)
    }

    @Test func doubleTapGoesToFillThenBackToFit() {
        let fit: CGFloat = 0.2
        let fill: CGFloat = 0.8
        #expect(ZoomRules.doubleTapTargetScale(current: fit, fit: fit, fill: fill) == fill)
        #expect(ZoomRules.doubleTapTargetScale(current: fill, fit: fit, fill: fill) == fit)
        // Mid-pinch values come back to fit too.
        #expect(ZoomRules.doubleTapTargetScale(current: 0.5, fit: fit, fill: fill) == fit)
    }

    @Test func doubleTapOnASameRatioPhotoStillZooms() {
        let fit: CGFloat = 0.4
        let target = ZoomRules.doubleTapTargetScale(current: fit, fit: fit, fill: fit)
        #expect(abs(target - fit * 2.5) < 0.0001)
        #expect(target <= ZoomRules.maxScale(fit: fit))
        // And a second double tap comes back to fit.
        #expect(ZoomRules.doubleTapTargetScale(current: target, fit: fit, fill: fit) == fit)
    }

    @Test func slightZoomIsNotZoomed() {
        let fit: CGFloat = 0.4
        let slightlyZoomed: CGFloat = fit * 1.005
        let zoomed: CGFloat = fit * 1.02
        #expect(ZoomRules.isZoomed(current: slightlyZoomed, fit: fit) == false)
        #expect(ZoomRules.isZoomed(current: zoomed, fit: fit))
    }

    @Test func dismissOnDistance() {
        #expect(!DismissRules.shouldDismiss(translationY: 0.15 * 800, velocityY: 0, height: 800))
        #expect(DismissRules.shouldDismiss(translationY: 0.16 * 800, velocityY: 0, height: 800))
        // Up counts like down.
        #expect(DismissRules.shouldDismiss(translationY: -0.16 * 800, velocityY: 0, height: 800))
    }

    @Test func dismissOnVelocity() {
        #expect(!DismissRules.shouldDismiss(translationY: 10, velocityY: 800, height: 800))
        #expect(DismissRules.shouldDismiss(translationY: 10, velocityY: 801, height: 800))
        #expect(DismissRules.shouldDismiss(translationY: 10, velocityY: -801, height: 800))
    }

    @Test func dismissProgressIsCappedAtOne() {
        #expect(DismissRules.progress(translationY: 0, height: 800) == 0)
        #expect(abs(DismissRules.progress(translationY: 160, height: 800) - 0.5) < 0.0001)
        #expect(abs(DismissRules.progress(translationY: -160, height: 800) - 0.5) < 0.0001)
        #expect(DismissRules.progress(translationY: 5000, height: 800) == 1)
    }

    @Test func pagingIndexSwitchesAtHalfWidthAndClamps() {
        #expect(PagingRules.index(offsetX: 49, pageWidth: 100, count: 3) == 0)
        #expect(PagingRules.index(offsetX: 50, pageWidth: 100, count: 3) == 1)
        #expect(PagingRules.index(offsetX: 980, pageWidth: 100, count: 3) == 2)
        #expect(PagingRules.index(offsetX: -80, pageWidth: 100, count: 3) == 0)
    }

    @Test func pagerLeavesTheMostlyVerticalDragsToTheDismiss() {
        // A slightly diagonal downward drag closes, never pages.
        #expect(!PagingRules.pagerPanShouldBegin(velocity: CGPoint(x: 120, y: 200)))
        #expect(!PagingRules.pagerPanShouldBegin(velocity: CGPoint(x: -120, y: -200)))
        #expect(PagingRules.pagerPanShouldBegin(velocity: CGPoint(x: 200, y: 120)))
        // A perfectly diagonal drag pages: the dismiss needs a mostly vertical one.
        #expect(PagingRules.pagerPanShouldBegin(velocity: CGPoint(x: 100, y: 100)))
        #expect(!DismissRules.isMostlyVertical(velocity: CGPoint(x: 100, y: 100)))
    }

    @Test func dismissDragBeginsOnlyVerticalAtFitWithThePagerAtRest() {
        let vertical = CGPoint(x: 120, y: 200)
        #expect(DismissRules.dragShouldBegin(velocity: vertical, isZoomed: false, isPaging: false))
        #expect(!DismissRules.dragShouldBegin(velocity: CGPoint(x: 200, y: 120), isZoomed: false, isPaging: false))
        #expect(!DismissRules.dragShouldBegin(velocity: vertical, isZoomed: true, isPaging: false))
        // Mid-deceleration between two photos.
        #expect(!DismissRules.dragShouldBegin(velocity: vertical, isZoomed: false, isPaging: true))
    }

    @Test func infoEqualityIgnoresTheCallback() {
        let url = URL(string: "https://example.com/a.jpg")!
        let items = [ZoomableImageInfo.Item(url: url, image: nil, transitionImage: nil)]
        let frame = CGRect(x: 1, y: 2, width: 3, height: 4)
        let a = ZoomableImageInfo(
            items: items, index: 0, sourceFrame: frame, sourceCornerRadius: 8, onDismiss: { _ in })
        let b = ZoomableImageInfo(items: items, index: 0, sourceFrame: frame, sourceCornerRadius: 8, onDismiss: nil)
        #expect(a == b)
        let otherIndex = ZoomableImageInfo(items: items + items, index: 1, sourceFrame: frame, sourceCornerRadius: 8)
        #expect(a != otherIndex)
        let otherFrame = ZoomableImageInfo(items: items, index: 0, sourceFrame: nil, sourceCornerRadius: 8)
        #expect(a != otherFrame)
        #expect(a.url == url)
    }
}
