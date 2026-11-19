//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit
import Testing
@testable import OctopusUI

/// Where a pinched photo is drawn, and how the pinch fits in its screen.
struct InPlacePinchZoomTransformTests {
    @Test func scaleClampsAtBothLimitsUsingTheEffectiveZoomRatio() {
        var transform = InPlacePinchZoomTransform()
        let centroid = CGPoint(x: 50, y: 50)
        transform.apply(zoom: 10, from: centroid, to: centroid)
        #expect(transform.scale == InPlacePinchZoomTransform.maxScale)
        #expect(transform.offset == CGPoint(x: -150, y: -150))

        // Spreading further at the limit does not move the photo.
        transform.apply(zoom: 2, from: centroid, to: centroid)
        #expect(transform.scale == 4)
        #expect(transform.offset == CGPoint(x: -150, y: -150))

        // Pinching past the size at rest stops at it, and the point under the fingers stays there.
        transform.apply(zoom: 0.01, from: centroid, to: centroid)
        #expect(transform.scale == 1)
        #expect(transform.isIdentity)
    }

    @Test func theSamePointOfThePhotoFollowsAMovingOffCenterFocalPoint() {
        var transform = InPlacePinchZoomTransform()
        let grabbed = CGPoint(x: 30, y: 40)
        transform.apply(zoom: 2, from: grabbed, to: CGPoint(x: 60, y: 90))
        #expect(transform.scale == 2)
        // The point (30, 40) of the photo is drawn under the fingers.
        let drawn = CGPoint(
            x: transform.offset.x + grabbed.x * transform.scale,
            y: transform.offset.y + grabbed.y * transform.scale)
        #expect(drawn == CGPoint(x: 60, y: 90))

        // Moving the fingers without spreading them only translates the photo.
        transform.apply(zoom: 1, from: CGPoint(x: 60, y: 90), to: CGPoint(x: 70, y: 80))
        #expect(transform.scale == 2)
        #expect(transform.offset == CGPoint(x: 10, y: 0))
    }

    @Test(arguments: [(CGFloat(1), CGFloat(0)), (2.5, 0.3), (4, 0.6)])
    func theBackdropDarkensWithTheScale(scale: CGFloat, dimAlpha: CGFloat) {
        var transform = InPlacePinchZoomTransform()
        transform.apply(zoom: scale, from: .zero, to: .zero)
        #expect(abs(transform.dimAlpha - dimAlpha) < 0.0001)
    }

    @Test func aFrameAndItsSourceGiveBackTheTransformThatDrawsIt() {
        let source = CGRect(x: 20, y: 100, width: 200, height: 100)
        var transform = InPlacePinchZoomTransform()
        transform.apply(zoom: 3, from: CGPoint(x: 100, y: 50), to: CGPoint(x: 120, y: 40))
        let frame = transform.frame(for: source)
        #expect(frame.size == CGSize(width: 600, height: 300))
        #expect(InPlacePinchZoomTransform(frame: frame, source: source) == transform)
    }

    @Test(arguments: [0, -1, CGFloat.nan, CGFloat.infinity])
    func anInvalidZoomLeavesThePhotoWhereItIs(zoom: CGFloat) {
        var transform = InPlacePinchZoomTransform()
        transform.apply(zoom: zoom, from: .zero, to: CGPoint(x: 10, y: 10))
        #expect(transform.isIdentity)
    }
}

@MainActor
struct InPlacePinchZoomViewTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
    private let screen = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
    private let photo = InPlacePinchZoomView(frame: CGRect(x: 0, y: 100, width: 300, height: 200))
    private let zoomingChanges = Recorder<Bool>()
    /// The returns of the photo, recorded rather than played.
    private let returns = Recorder<(animations: @MainActor () -> Void, completion: @MainActor () -> Void)>()

    init() {
        window.addSubview(screen)
        screen.addSubview(photo)
        photo.isZoomEnabled = true
        photo.makeContent = { UIView() }
        photo.onZoomingChanged = { [zoomingChanges] in zoomingChanges.values.append($0) }
        photo.animateReturn = { [returns] animations, completion in
            returns.values.append((animations, completion))
            return nil
        }
        photo.scheduleOverlayRemoval = { $0() }
    }

    /// Plays the last return of the photo to its place.
    private func finishReturn() {
        guard let last = returns.values.last else { return }
        last.animations()
        last.completion()
    }

    @Test func thePinchDrawsACopyOfThePhotoAboveTheWindowThenPutsItBack() throws {
        #expect(photo.beginZoom(centroid: CGPoint(x: 150, y: 200)))
        let overlay = try #require(photo.overlayView)
        #expect(overlay.superview === window)
        #expect(window.subviews.last === overlay)
        #expect(photo.zoomedContentView?.frame == CGRect(x: 0, y: 100, width: 300, height: 200))
        #expect(zoomingChanges.values == [true])

        photo.updateZoom(zoom: 2, centroid: CGPoint(x: 150, y: 200))
        #expect(photo.zoomedContentView?.frame == CGRect(x: -150, y: 0, width: 600, height: 400))
        #expect(photo.dimAlpha > 0)

        photo.releaseZoom()
        // Still drawn by the overlay on its way back.
        #expect(photo.isZooming)
        // The fingers can no longer move it.
        photo.updateZoom(zoom: 2, centroid: .zero)
        finishReturn()
        #expect(!photo.isZooming)
        #expect(overlay.superview == nil)
        #expect(zoomingChanges.values == [true, false])
    }

    @Test func nothingIsZoomedWithoutACopyToDrawOrWhenDisabled() {
        photo.makeContent = { nil }
        #expect(!photo.beginZoom(centroid: .zero))
        photo.makeContent = { UIView() }
        photo.isZoomEnabled = false
        #expect(!photo.beginZoom(centroid: .zero))
        #expect(window.subviews == [screen])
        #expect(zoomingChanges.values.isEmpty)
    }

    @Test func theScrollViewsAroundThePhotoHoldStillUntilThePhotoIsBack() {
        let feed = UIScrollView(frame: screen.bounds)
        feed.contentSize = CGSize(width: 300, height: 2000)
        let disabledScroll = UIScrollView(frame: feed.bounds)
        screen.addSubview(feed)
        feed.addSubview(disabledScroll)
        disabledScroll.addSubview(photo)
        // Once in the window: a scroll view entering one turns its pan back on.
        disabledScroll.panGestureRecognizer.isEnabled = false

        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        #expect(!feed.panGestureRecognizer.isEnabled)
        #expect(!disabledScroll.panGestureRecognizer.isEnabled)

        photo.releaseZoom()
        // Held through the return.
        #expect(!feed.panGestureRecognizer.isEnabled)
        finishReturn()
        #expect(feed.panGestureRecognizer.isEnabled)
        #expect(!disabledScroll.panGestureRecognizer.isEnabled)
    }

    @Test func aCarouselPageInItsOwnControllerHoldsTheScrollViewsOfItsScreenOnly() {
        // The host app shows the SDK in its own scroll view; the SDK screen is in a navigation controller; its feed
        // holds a carousel whose pages are the view of a child controller, like `PagingScrollView`.
        let host = UIViewController()
        let hostScroll = UIScrollView(frame: window.bounds)
        let feedScreen = UIViewController()
        let navigation = UINavigationController(rootViewController: feedScreen)
        let feed = UIScrollView(frame: window.bounds)
        feed.contentSize = CGSize(width: 300, height: 2000)
        let carousel = UIScrollView(frame: CGRect(x: 0, y: 100, width: 300, height: 200))
        carousel.isPagingEnabled = true
        carousel.contentSize = CGSize(width: 900, height: 200)
        let pages = UIViewController()
        pages.view.frame = CGRect(x: 0, y: 0, width: 900, height: 200)
        photo.frame = CGRect(x: 300, y: 0, width: 300, height: 200)

        window.addSubview(host.view)
        host.view.addSubview(hostScroll)
        host.addChild(navigation)
        hostScroll.addSubview(navigation.view)
        navigation.didMove(toParent: host)
        // A navigation controller in a window that is not shown does not lay its screen out: done by hand.
        navigation.view.addSubview(feedScreen.view)
        feedScreen.view.addSubview(feed)
        feed.addSubview(carousel)
        feedScreen.addChild(pages)
        carousel.addSubview(pages.view)
        pages.didMove(toParent: feedScreen)
        pages.view.addSubview(photo)

        #expect(InPlacePinchZoomView.screenView(of: photo) === feedScreen.view)
        #expect(photo.beginZoom(centroid: CGPoint(x: 150, y: 200)))
        #expect(!carousel.panGestureRecognizer.isEnabled)
        #expect(!feed.panGestureRecognizer.isEnabled)
        #expect(hostScroll.panGestureRecognizer.isEnabled)
        photo.releaseZoom()
        finishReturn()
        #expect(carousel.panGestureRecognizer.isEnabled)
        #expect(feed.panGestureRecognizer.isEnabled)
    }

    @Test func twoZoomsOverlappingOnOneFeedLetItScrollOnceBothAreBack() {
        let feed = UIScrollView(frame: screen.bounds)
        feed.contentSize = CGSize(width: 300, height: 2000)
        let other = InPlacePinchZoomView(frame: CGRect(x: 0, y: 320, width: 300, height: 200))
        other.isZoomEnabled = true
        other.makeContent = { UIView() }
        other.animateReturn = photo.animateReturn
        other.scheduleOverlayRemoval = { $0() }
        screen.addSubview(feed)
        feed.addSubview(photo)
        feed.addSubview(other)

        // The first photo is on its way back when the second is pinched.
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        photo.releaseZoom()
        other.beginZoom(centroid: CGPoint(x: 150, y: 420))
        let firstReturn = returns.values[0]
        firstReturn.animations()
        firstReturn.completion()
        #expect(!photo.isZooming)
        #expect(!feed.panGestureRecognizer.isEnabled)

        other.releaseZoom()
        finishReturn()
        #expect(feed.panGestureRecognizer.isEnabled)
    }

    @Test(arguments: [
        // Pulled 80 points past the top, with a 20 points inset.
        (CGPoint(x: 0, y: -100), CGPoint(x: 0, y: -20)),
        // Pushed past the bottom: 2000 of content, 600 of height.
        (CGPoint(x: 0, y: 1500), CGPoint(x: 0, y: 1400)),
        (CGPoint(x: 0, y: 700), CGPoint(x: 0, y: 700)),
    ])
    func aHeldScrollViewComesBackWithinItsContent(offset: CGPoint, expected: CGPoint) {
        let resting = ScrollViewHold.restingOffset(
            of: offset, contentSize: CGSize(width: 300, height: 2000), size: CGSize(width: 300, height: 600),
            insets: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0))
        #expect(resting == expected)
    }

    @Test(arguments: [
        // The third page holds the photo, whichever side of it the swipe went.
        (CGFloat(600), CGFloat(630), CGFloat(600)),
        (600, 570, 600),
        // Never past the end of the content.
        (1200, 1100, 1050),
    ])
    func thePageOfThePhotoIsTheOneItCovers(photoX: CGFloat, current: CGFloat, expected: CGFloat) {
        let offset = InPlacePinchZoomView.pageOffset(
            of: CGRect(x: photoX, y: 0, width: 300, height: 200), in: CGSize(width: 300, height: 200),
            contentSize: CGSize(width: 1350, height: 200), current: CGPoint(x: current, y: 0))
        #expect(offset == CGPoint(x: expected, y: 0))
    }

    @Test func theReturnLandsThePhotoWhereItsPageSettles() {
        let carousel = UIScrollView(frame: CGRect(x: 0, y: 100, width: 300, height: 200))
        carousel.isPagingEnabled = true
        carousel.contentSize = CGSize(width: 1500, height: 200)
        carousel.contentOffset = CGPoint(x: 630, y: 0)
        photo.frame = CGRect(x: 600, y: 0, width: 300, height: 200)
        screen.addSubview(carousel)
        carousel.addSubview(photo)
        var landing: CGRect?
        photo.animateReturn = { [photo] animations, _ in
            animations()
            landing = photo.zoomedContentView?.frame
            return nil
        }

        // Five pages of 300; the photo is the third, and the member swiped 30 points toward the fourth. The copy
        // starts where the photo is drawn, 30 points to the left, and the carousel holds there.
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        #expect(photo.zoomedContentView?.frame == CGRect(x: -30, y: 100, width: 300, height: 200))
        #expect(carousel.contentOffset.x == 630)
        photo.updateZoom(zoom: 2, centroid: CGPoint(x: 150, y: 200))
        photo.releaseZoom()
        // Where its page settles, not where the swipe had left it.
        #expect(landing == CGRect(x: 0, y: 100, width: 300, height: 200))
    }

    @Test func theCopyStaysAboveThePhotoUntilThePhotoIsShownAgain() throws {
        var removals: [@MainActor () -> Void] = []
        photo.scheduleOverlayRemoval = { removals.append($0) }
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        let overlay = try #require(photo.overlayView)
        photo.releaseZoom()
        finishReturn()
        #expect(zoomingChanges.values == [true, false])
        #expect(overlay.superview === window)

        photo.photoIsShown()
        #expect(overlay.superview == nil)
        // The fallback, for an owner that never says so, does nothing more.
        removals.forEach { $0() }
        #expect(photo.overlayView == nil)
    }

    @Test func aCopyDrawnLaterKeepsThePhotoShownUntilItIsDrawn() throws {
        let content = DeferredContent()
        photo.makeContent = { content }
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        #expect(zoomingChanges.values.isEmpty)
        content.becomeReady()
        #expect(zoomingChanges.values == [true])
        photo.releaseZoom()
        finishReturn()
        #expect(zoomingChanges.values == [true, false])

        // Ended before the copy is drawn: the photo was never hidden.
        let late = DeferredContent()
        photo.makeContent = { late }
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        let overlay = try #require(photo.overlayView)
        photo.releaseZoom()
        finishReturn()
        late.becomeReady()
        #expect(overlay.superview == nil)
        #expect(zoomingChanges.values == [true, false])
    }

    @Test func aPartOfThePhotoClippedAwayCannotBePinched() {
        // A clipping container shows the top 50 points of the photo only.
        let container = UIView(frame: CGRect(x: 0, y: 100, width: 300, height: 50))
        container.clipsToBounds = true
        screen.addSubview(container)
        photo.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        container.addSubview(photo)
        #expect(photo.showsPhoto(at: CGPoint(x: 150, y: 120)))
        #expect(!photo.showsPhoto(at: CGPoint(x: 150, y: 200)))
        #expect(!photo.showsPhoto(at: CGPoint(x: 150, y: 400)))
    }

    @Test func aPinchThatCannotZoomIsRefusedBeforeItBegins() {
        #expect(photo.gestureRecognizerShouldBegin(photo.pinchRecognizer))
        photo.makeContent = nil
        #expect(!photo.gestureRecognizerShouldBegin(photo.pinchRecognizer))
    }

    @Test func aPinchCatchesThePhotoOnItsWayBack() {
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        photo.updateZoom(zoom: 2, centroid: CGPoint(x: 150, y: 200))
        photo.releaseZoom()
        #expect(photo.beginZoom(centroid: CGPoint(x: 150, y: 200)))
        // Carries on from where it was drawn, and the old return no longer ends the zoom.
        #expect(photo.zoomedContentView?.frame.width == 600)
        returns.values.first?.completion()
        #expect(photo.isZooming)
        #expect(zoomingChanges.values == [true])

        photo.updateZoom(zoom: 1.5, centroid: CGPoint(x: 150, y: 200))
        #expect(photo.zoomedContentView?.frame.width == 900)
        photo.releaseZoom()
        finishReturn()
        #expect(!photo.isZooming)
        #expect(zoomingChanges.values == [true, false])
    }

    @Test func leavingTheWindowEndsTheZoomAtOnce() async throws {
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        let overlay = try #require(photo.overlayView)
        photo.removeFromSuperview()
        #expect(!photo.isZooming)
        #expect(overlay.superview == nil)
        // Told after the update that took the photo off the window.
        #expect(zoomingChanges.values == [true])
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(zoomingChanges.values == [true, false])
    }

    @Test func disablingThePinchSendsAZoomedPhotoBack() {
        photo.beginZoom(centroid: CGPoint(x: 150, y: 200))
        photo.isZoomEnabled = false
        #expect(returns.values.count == 1)
        finishReturn()
        #expect(!photo.isZooming)
    }

    @Test func thePinchRecognizerLivesOnTheWindowAndLeavesItWithThePhoto() {
        #expect(photo.pinchRecognizer.view === window)
        photo.removeFromSuperview()
        #expect(photo.pinchRecognizer.view == nil)
        #expect(window.gestureRecognizers?.contains(photo.pinchRecognizer) != true)
    }

    @Test func thePhotoNeverTakesATouchNorReadsToVoiceOver() {
        #expect(!photo.isUserInteractionEnabled)
        #expect(!photo.isAccessibilityElement)
        #expect(photo.accessibilityElementsHidden)
    }

    @Test func theFirstFingerHasToLandOnThePhotoInItsScreen() {
        let screenView = UIView()
        let inScreen = UIView()
        screenView.addSubview(inScreen)
        let presentedAbove = UIView()

        #expect(InPlacePinchZoomView.receivesTouch(
            isOnVisiblePhoto: true, touchView: inScreen, screenView: screenView, trackedTouches: 0, canZoom: true))
        // A bar over the photo, or a screen presented above it.
        #expect(!InPlacePinchZoomView.receivesTouch(
            isOnVisiblePhoto: true, touchView: presentedAbove, screenView: screenView, trackedTouches: 0, canZoom: true))
        #expect(!InPlacePinchZoomView.receivesTouch(
            isOnVisiblePhoto: false, touchView: inScreen, screenView: screenView, trackedTouches: 0, canZoom: true))
        #expect(!InPlacePinchZoomView.receivesTouch(
            isOnVisiblePhoto: true, touchView: inScreen, screenView: screenView, trackedTouches: 0, canZoom: false))
        // The second finger may land beside the photo.
        #expect(InPlacePinchZoomView.receivesTouch(
            isOnVisiblePhoto: false, touchView: presentedAbove, screenView: screenView, trackedTouches: 1, canZoom: true))
    }
}

@MainActor
private final class Recorder<Value> {
    var values: [Value] = []
}

@MainActor
private final class DeferredContent: UIView, InPlacePinchZoomDeferredContent {
    private var onReady: [@MainActor () -> Void] = []

    func whenReadyForDisplay(_ ready: @escaping @MainActor () -> Void) {
        onReady.append(ready)
    }

    func becomeReady() {
        onReady.forEach { $0() }
        onReady = []
    }
}
