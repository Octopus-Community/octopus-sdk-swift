//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// Lets the member pinch a photo where it is: the photo grows under the fingers, above everything else on screen
/// (the feed, the bars) with a darkening backdrop, and springs back into place when the fingers lift.
///
/// This view sits behind the photo, at its frame, and never takes a touch: its pinch recognizer is on the window,
/// where it sees the two fingers even when they cross the bounds of the cell, of the carousel or of the scroll view.
/// It only takes a pinch whose first finger lands on the visible part of the photo, in the screen of the photo: not
/// one in a screen presented above it, such as the fullscreen viewer, nor one on a bar drawn over the photo.
///
/// While the photo is zoomed, a copy of it is drawn in an overlay added to the window, and the photo itself is
/// hidden by its owner (`onZoomingChanged`). The scroll views of the screen around the photo hold still: neither the
/// feed nor the carousel moves under the fingers, and the carousel settles back on the photo's page once the photo
/// is back.
@MainActor
final class InPlacePinchZoomView: UIView, UIGestureRecognizerDelegate {
    /// Runs the return of the photo to its place, then `completion`. Returns the animator, which is stopped when
    /// a new pinch catches the photo on its way back. Replaced in tests, which run it at once.
    typealias AnimateReturn = @MainActor (
        _ animations: @escaping @MainActor () -> Void,
        _ completion: @escaping @MainActor () -> Void) -> UIViewPropertyAnimator?

    /// Whether a new pinch may start. Turning it off sends a zoomed photo back.
    var isZoomEnabled = false {
        didSet {
            if !isZoomEnabled && session?.isReturning == false {
                releaseZoom()
            }
        }
    }
    /// The radius of the corners of the photo at rest, given to its copy so that it lands with the same shape.
    var cornerRadius: CGFloat = 0
    /// The corners rounded by `cornerRadius`.
    var roundedCorners: CACornerMask = .allCorners
    /// Makes the copy of the photo drawn while it is zoomed, filling the frame it is given; `nil` when there is
    /// nothing to show yet, which leaves the pinch to the views below. A copy that is not drawn at once conforms to
    /// `InPlacePinchZoomDeferredContent`: the photo stays shown until the copy is.
    var makeContent: (@MainActor () -> UIView?)?
    /// Told when the copy is drawn instead of the photo (`true`), and when the photo has to be shown again (`false`).
    /// The owner then calls `photoIsShown()` once it shows the photo.
    var onZoomingChanged: (@MainActor (Bool) -> Void)?

    var animateReturn: AnimateReturn = { animations, completion in
        // Critically damped: the photo comes back without shrinking past its size.
        let animator = UIViewPropertyAnimator(duration: 0.35, dampingRatio: 1, animations: animations)
        animator.addCompletion { _ in MainActor.assumeIsolated { completion() } }
        animator.startAnimation()
        return animator
    }
    /// Removes the overlay if the owner never says that the photo is shown again. Replaced in tests.
    var scheduleOverlayRemoval: @MainActor (_ removal: @escaping @MainActor () -> Void) -> Void = { removal in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { MainActor.assumeIsolated { removal() } }
    }

    let pinchRecognizer = UIPinchGestureRecognizer()

    /// Whether the photo is drawn by the overlay, from the first pinch until it is back in place.
    var isZooming: Bool { session != nil }
    /// The overlay drawn above the window, while zooming and until the photo is shown again.
    var overlayView: UIView? { session?.overlay ?? landedOverlay }
    /// The copy of the photo in the overlay.
    var zoomedContentView: UIView? { session?.contentView }
    /// The opacity of the backdrop.
    var dimAlpha: CGFloat { session?.dimView.alpha ?? 0 }

    private var session: Session?
    /// The overlay of a photo that is back in place, kept above it until its owner shows it again: removing it
    /// first would leave a frame with neither.
    private var landedOverlay: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        pinchRecognizer.addTarget(self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        // The views below keep their touches until the pinch is recognized; then they are cancelled, so that the
        // pinch is neither a tap nor a scroll.
        pinchRecognizer.delaysTouchesEnded = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if pinchRecognizer.view !== window {
            pinchRecognizer.view?.removeGestureRecognizer(pinchRecognizer)
            window?.addGestureRecognizer(pinchRecognizer)
        }
        if window == nil {
            endZoom(removingOverlayAtOnce: true)
            removeLandedOverlay()
        }
    }

    // MARK: Zoom

    /// Starts drawing the copy of the photo with the fingers at `centroid`, in the window, or catches the photo on
    /// its way back. Returns false when the photo cannot be zoomed.
    @discardableResult
    func beginZoom(centroid: CGPoint) -> Bool {
        if let session {
            guard session.isReturning else { return false }
            // Caught on its way back: carry on from where it is drawn now.
            let frame = session.contentView.layer.presentation()?.frame ?? session.contentView.frame
            session.animator?.stopAnimation(true)
            session.animator = nil
            session.isReturning = false
            session.transform = InPlacePinchZoomTransform(frame: frame, source: session.source)
            session.lastCentroid = centroid
            session.layOut()
            return true
        }
        guard isZoomEnabled, let window, bounds.width > 0, bounds.height > 0,
              let contentView = makeContent?() else { return false }
        removeLandedOverlay()
        // Held before the photo is measured: bringing an overscrolled feed back within its content moves the photo.
        let scrollViews = scrollViewsOfScreen()
        scrollViews.forEach(ScrollViewHold.hold)
        let source = convert(bounds, to: window)

        let overlay = UIView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.isUserInteractionEnabled = false
        overlay.accessibilityElementsHidden = true
        let dimView = UIView(frame: overlay.bounds)
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.backgroundColor = .black
        dimView.alpha = 0
        overlay.addSubview(dimView)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = cornerRadius
        contentView.layer.maskedCorners = roundedCorners
        overlay.addSubview(contentView)
        window.addSubview(overlay)

        let session = Session(
            overlay: overlay, dimView: dimView, contentView: contentView, source: source, centroid: centroid,
            scrollViews: scrollViews)
        session.layOut()
        self.session = session

        if let deferred = contentView as? InPlacePinchZoomDeferredContent {
            deferred.whenReadyForDisplay { [weak self, weak session] in
                guard let self, let session, self.session === session else { return }
                self.hidePhoto(for: session)
            }
        } else {
            hidePhoto(for: session)
        }
        return true
    }

    private func hidePhoto(for session: Session) {
        guard !session.isPhotoHidden else { return }
        session.isPhotoHidden = true
        onZoomingChanged?(true)
    }

    /// Follows the fingers, now at `centroid` in the window, after the distance between them was multiplied by
    /// `zoom` since the last call.
    func updateZoom(zoom: CGFloat, centroid: CGPoint) {
        guard let session, !session.isReturning else { return }
        let origin = session.source.origin
        session.transform.apply(
            zoom: zoom,
            from: CGPoint(x: session.lastCentroid.x - origin.x, y: session.lastCentroid.y - origin.y),
            to: CGPoint(x: centroid.x - origin.x, y: centroid.y - origin.y))
        session.lastCentroid = centroid
        session.layOut()
    }

    /// Sends the photo back to its place. It is shown again once it has landed.
    func releaseZoom() {
        guard let session, !session.isReturning else { return }
        session.isReturning = true
        let target = restingFrame(settlingPageOf: session.scrollViews)
        session.animator = animateReturn({
            session.contentView.frame = target
            session.dimView.alpha = 0
        }, { [weak self, weak session] in
            guard let self, let session, self.session === session, session.isReturning else { return }
            self.endZoom(removingOverlayAtOnce: false)
        })
    }

    /// Ends the zoom wherever the copy is, and asks for the photo to be shown again.
    ///
    /// - Parameter removingOverlayAtOnce: removes the copy now rather than once the photo is shown again. For a
    ///   photo that leaves the screen, which is not drawn anymore.
    func endZoom(removingOverlayAtOnce: Bool) {
        guard let session else { return }
        self.session = nil
        session.animator?.stopAnimation(true)
        session.scrollViews.forEach(ScrollViewHold.release)
        let overlay = session.overlay
        guard session.isPhotoHidden else {
            // The photo was never hidden.
            overlay.removeFromSuperview()
            return
        }
        if removingOverlayAtOnce {
            overlay.removeFromSuperview()
            // Not during the SwiftUI update that may have taken the photo off the window.
            let onZoomingChanged = onZoomingChanged
            DispatchQueue.main.async { MainActor.assumeIsolated { onZoomingChanged?(false) } }
        } else {
            landedOverlay = overlay
            onZoomingChanged?(false)
            // The overlay is kept here rather than by this view, which may be gone by then.
            scheduleOverlayRemoval { [weak self] in
                overlay.removeFromSuperview()
                if self?.landedOverlay === overlay {
                    self?.landedOverlay = nil
                }
            }
        }
    }

    /// Told by the owner that it shows the photo again: the copy above it can go.
    func photoIsShown() {
        removeLandedOverlay()
    }

    private func removeLandedOverlay() {
        landedOverlay?.removeFromSuperview()
        landedOverlay = nil
    }

    // MARK: Scroll views

    /// The scroll views around the photo, from the innermost, up to the view of its screen: the scroll views of the
    /// host app, around the SDK, are left alone.
    private func scrollViewsOfScreen() -> [UIScrollView] {
        let screenView = screenView
        var scrollViews = [UIScrollView]()
        var view = superview
        while let current = view {
            if let scrollView = current as? UIScrollView {
                scrollViews.append(scrollView)
            }
            if current === screenView { break }
            view = current.superview
        }
        return scrollViews
    }

    /// The frame of the photo in its window once it is back, and the carousel moving back to its page.
    private func restingFrame(settlingPageOf scrollViews: [UIScrollView]) -> CGRect {
        guard let window else { return session?.source ?? .zero }
        var frame = convert(bounds, to: window)
        // The innermost paging scroll view is the carousel of the photo.
        if let carousel = scrollViews.first(where: \.isPagingEnabled) {
            let offset = Self.pageOffset(
                of: convert(bounds, to: carousel), in: carousel.bounds.size, contentSize: carousel.contentSize,
                current: carousel.contentOffset)
            // Moving the content to `offset` moves the photo the other way.
            frame.origin.x += carousel.contentOffset.x - offset.x
            if offset != carousel.contentOffset {
                carousel.setContentOffset(offset, animated: true)
            }
        }
        return frame
    }

    /// The content offset of a horizontal paging scroll view of size `pageSize` that shows the page holding the
    /// photo, whose frame in the content is `photoFrame`.
    static func pageOffset(of photoFrame: CGRect, in pageSize: CGSize, contentSize: CGSize,
                           current: CGPoint) -> CGPoint {
        guard pageSize.width > 0 else { return current }
        let page = (photoFrame.midX / pageSize.width).rounded(.down)
        let maxX = max(contentSize.width - pageSize.width, 0)
        return CGPoint(x: min(max(page * pageSize.width, 0), maxX), y: current.y)
    }

    // MARK: Gesture

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let window else { return }
        let centroid = recognizer.location(in: window)
        switch recognizer.state {
        case .began:
            guard beginZoom(centroid: centroid) else {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                return
            }
            updateZoom(zoom: recognizer.scale, centroid: centroid)
            recognizer.scale = 1
        case .changed:
            // A lifted finger sends the photo back; the other one stays with the pinch until it lifts too, so that
            // it neither scrolls nor taps.
            if recognizer.numberOfTouches < 2 {
                releaseZoom()
            } else {
                updateZoom(zoom: recognizer.scale, centroid: centroid)
                recognizer.scale = 1
            }
        case .ended, .cancelled, .failed:
            releaseZoom()
        default:
            break
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Refused before it is recognized, so that the views below keep their touches.
        session?.isReturning == true || (isZoomEnabled && window != nil && makeContent != nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        Self.receivesTouch(
            isOnVisiblePhoto: showsPhoto(at: touch.location(in: nil)),
            touchView: touch.view,
            screenView: screenView,
            trackedTouches: gestureRecognizer.numberOfTouches,
            canZoom: isZoomEnabled || session?.isReturning == true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // The scroll views and the taps of the screen still start: the pinch stops them itself once it is
        // recognized. A gesture outside the screen, such as the pan that dismisses a sheet, does not run with it.
        guard let otherView = otherGestureRecognizer.view, let screenView else { return true }
        return otherView === window || otherView.isDescendant(of: screenView)
    }

    /// Whether the pinch takes a touch.
    ///
    /// The first finger has to land on the visible part of the photo, on a view of its screen: a screen presented
    /// above it or a bar drawn over it has the touch. Once it has one finger, the pinch takes the second wherever it
    /// lands.
    static func receivesTouch(isOnVisiblePhoto: Bool, touchView: UIView?, screenView: UIView?, trackedTouches: Int,
                              canZoom: Bool) -> Bool {
        guard canZoom else { return false }
        if trackedTouches > 0 { return true }
        guard isOnVisiblePhoto, let touchView, let screenView else { return false }
        return touchView.isDescendant(of: screenView)
    }

    /// Whether `point`, in the window, is on the photo and not clipped away by a view around it, up to its screen:
    /// a photo scrolled under the composer of a post, or the next page of a carousel, cannot be pinched.
    func showsPhoto(at point: CGPoint) -> Bool {
        guard let window else { return false }
        guard bounds.contains(convert(point, from: window)) else { return false }
        let screenView = screenView
        var view = superview
        while let current = view {
            if current.clipsToBounds && !current.bounds.contains(current.convert(point, from: window)) {
                return false
            }
            if current === screenView { break }
            view = current.superview
        }
        return true
    }

    /// The view of the screen that shows the photo: the controller of the photo and the controllers around it, up
    /// to a navigation, tab or split container, or to a presentation. A carousel page has a controller of its own,
    /// inside the scroll view of the carousel, inside the feed: they all belong to the screen of the feed.
    private var screenView: UIView? {
        Self.screenView(of: self) ?? window
    }

    static func screenView(of view: UIView) -> UIView? {
        var screenView: UIView?
        var current: UIView? = view
        while let candidate = current {
            if let controller = candidate.next as? UIViewController {
                if isContainer(controller) { break }
                screenView = candidate
                if let parent = controller.parent {
                    if isContainer(parent) { break }
                } else if controller.presentingViewController != nil {
                    break
                }
            }
            current = candidate.superview
        }
        return screenView
    }

    private static func isContainer(_ controller: UIViewController) -> Bool {
        controller is UINavigationController || controller is UITabBarController
            || controller is UISplitViewController
    }
}

/// A copy of a zoomed view that is not drawn as soon as it is made, such as a new layer of a video player.
@MainActor
protocol InPlacePinchZoomDeferredContent: UIView {
    /// Calls `ready` once the view draws what it shows, at once when it already does.
    func whenReadyForDisplay(_ ready: @escaping @MainActor () -> Void)
}

/// The scroll views held still by zooms. Two photos of a feed can be zoomed at once, one landing while the other
/// starts: a scroll view scrolls again when the last of its zooms ends, as it did before the first.
@MainActor
enum ScrollViewHold {
    private struct Hold {
        /// Tells a hold of this scroll view from one of a released scroll view that had the same address.
        weak var scrollView: UIScrollView?
        /// The zooms holding the scroll view.
        var zooms: Int
        let wasPanEnabled: Bool
    }

    private static var holds: [ObjectIdentifier: Hold] = [:]

    /// Stops `scrollView` where it is: a fling stops, a page swipe holds rather than settling on a neighbour, an
    /// overscroll goes back within the content, and the fingers no longer drag it. Disabling the pan cancels the drag
    /// in progress.
    static func hold(_ scrollView: UIScrollView) {
        let key = ObjectIdentifier(scrollView)
        if var hold = holds[key], hold.scrollView === scrollView {
            hold.zooms += 1
            holds[key] = hold
            return
        }
        holds[key] = Hold(
            scrollView: scrollView, zooms: 1, wasPanEnabled: scrollView.panGestureRecognizer.isEnabled)
        scrollView.panGestureRecognizer.isEnabled = false
        scrollView.setContentOffset(
            restingOffset(
                of: scrollView.contentOffset, contentSize: scrollView.contentSize, size: scrollView.bounds.size,
                insets: scrollView.adjustedContentInset),
            animated: false)
    }

    static func release(_ scrollView: UIScrollView) {
        let key = ObjectIdentifier(scrollView)
        guard var hold = holds[key], hold.scrollView === scrollView else { return }
        hold.zooms -= 1
        guard hold.zooms == 0 else {
            holds[key] = hold
            return
        }
        holds[key] = nil
        scrollView.panGestureRecognizer.isEnabled = hold.wasPanEnabled
    }

    /// `offset`, brought back within the content and its insets.
    static func restingOffset(of offset: CGPoint, contentSize: CGSize, size: CGSize,
                              insets: UIEdgeInsets) -> CGPoint {
        let minX = -insets.left
        let minY = -insets.top
        let maxX = max(contentSize.width + insets.right - size.width, minX)
        let maxY = max(contentSize.height + insets.bottom - size.height, minY)
        return CGPoint(x: min(max(offset.x, minX), maxX), y: min(max(offset.y, minY), maxY))
    }
}

/// One zoom, from the first pinch until the photo is back.
@MainActor
private final class Session {
    let overlay: UIView
    let dimView: UIView
    let contentView: UIView
    /// The frame of the photo in the window when the pinch started.
    let source: CGRect
    /// The scroll views held still, from the innermost.
    let scrollViews: [UIScrollView]
    var transform = InPlacePinchZoomTransform()
    var lastCentroid: CGPoint
    var isReturning = false
    /// Whether the owner hides the photo, which it does once the copy is drawn.
    var isPhotoHidden = false
    var animator: UIViewPropertyAnimator?

    init(overlay: UIView, dimView: UIView, contentView: UIView, source: CGRect, centroid: CGPoint,
         scrollViews: [UIScrollView]) {
        self.overlay = overlay
        self.dimView = dimView
        self.contentView = contentView
        self.source = source
        self.lastCentroid = centroid
        self.scrollViews = scrollViews
    }

    func layOut() {
        contentView.frame = transform.frame(for: source)
        dimView.alpha = transform.dimAlpha
    }
}

extension CACornerMask {
    static let allCorners: CACornerMask = [
        .layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    static let bottomCorners: CACornerMask = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
}
