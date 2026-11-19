//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// The transitions of the fullscreen viewer: the photo flies from its place on screen to the viewer, and back to
/// where its source is when the viewer closes. Without a source on screen, the viewer fades.
///
/// A presented controller only keeps a weak reference to its transitioning delegate: whoever presents the viewer
/// keeps this object alive until it is dismissed.
final class FullscreenViewerTransition: NSObject, UIViewControllerTransitioningDelegate {
    /// Runs the animations of a transition, then calls the completion with whether they finished. Replaced in tests.
    typealias AnimationRunner = @MainActor (
        _ duration: TimeInterval,
        _ animations: @escaping @MainActor () -> Void,
        _ completion: @escaping @MainActor (Bool) -> Void) -> Void

    /// Where the photo starts from, in window coordinates.
    let sourceFrame: CGRect?
    /// The corner radius of the source: the photo starts with it and lands back on it.
    let sourceCornerRadius: CGFloat
    /// The image shown by the source, as cropped for it. Without one, the viewer's photo is used.
    let sourceImage: UIImage?
    /// Where the photo flies back to when the viewer closes, in window coordinates. The initial source by default;
    /// the presenter can update it, for a carousel synced to the photo shown when the viewer closes.
    var dismissSourceFrame: @MainActor () -> CGRect?
    /// Whether the reader asked for reduced motion: the viewer then only fades.
    var isReduceMotionEnabled: @MainActor () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    /// Called when a dismissal starts to fade instead of flying back: no photo goes to the source, so the screen can
    /// show it again at once.
    var dismissalWillFade: @MainActor () -> Void = {}
    var runAnimation: AnimationRunner = FullscreenViewerTransition.springAnimation

    init(sourceFrame: CGRect?, sourceCornerRadius: CGFloat, sourceImage: UIImage?) {
        self.sourceFrame = sourceFrame
        self.sourceCornerRadius = sourceCornerRadius
        self.sourceImage = sourceImage
        dismissSourceFrame = { sourceFrame }
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FullscreenViewerAnimator(direction: .present, transition: self)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FullscreenViewerAnimator(direction: .dismiss, transition: self)
    }

    /// The spring of the other modal transitions of the SDK, which decelerates without bouncing.
    private static let springAnimation: AnimationRunner = { duration, animations, completion in
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0,
            options: [],
            animations: animations,
            completion: completion)
    }
}

/// The geometry of the flight between a photo's place on screen and the viewer.
enum HeroGeometry {
    /// The part of the source's area that must be in the window for the photo to fly from it, or back to it.
    private static let minimumVisibleFraction: CGFloat = 0.3

    /// The source frame the photo can fly from, or back to: `nil` when it is unknown, empty, or mostly out of the
    /// window, after a scroll or a rotation for instance. The viewer then fades instead.
    static func usableSourceFrame(_ frame: CGRect?, in windowBounds: CGRect) -> CGRect? {
        guard let frame, !frame.isNull, !frame.isInfinite, !frame.isEmpty else { return nil }
        let visible = frame.intersection(windowBounds)
        guard !visible.isNull else { return nil }
        let frameArea = frame.width * frame.height
        let visibleArea = visible.width * visible.height
        return visibleArea >= frameArea * minimumVisibleFraction ? frame : nil
    }

    /// The frame of a photo shown whole and centred in `bounds`, as the viewer shows it at fit.
    static func fitFrame(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        let scale = ZoomRules.fitScale(imageSize: imageSize, bounds: bounds.size)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}

/// The photo flying between its place on screen and the viewer: filling its frame and clipped, as the source is.
final class FullscreenViewerHeroSnapshot: UIView {
    let imageView = UIImageView()
    /// The viewer's photo, fading in over a source image cropped differently, so that the landing does not jump.
    private(set) var finalImageView: UIImageView?

    init(image: UIImage, finalImage: UIImage?) {
        super.init(frame: .zero)
        clipsToBounds = true
        isUserInteractionEnabled = false
        configure(imageView, image: image)
        if let finalImage, finalImage !== image {
            let finalImageView = UIImageView()
            configure(finalImageView, image: finalImage)
            finalImageView.alpha = 0
            self.finalImageView = finalImageView
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showFinalImage() {
        finalImageView?.alpha = 1
    }

    private func configure(_ imageView: UIImageView, image: UIImage) {
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.frame = bounds
        // Follows the frame of the snapshot inside the animation block.
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }
}

/// Presents or dismisses the fullscreen viewer, flying its photo from or back to the source.
final class FullscreenViewerAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    enum Direction {
        case present
        case dismiss
    }

    private enum Animation {
        static let duration: TimeInterval = 0.3
        /// The scale of the photo at the end of a dismissal that fades.
        static let fadingDismissScale: CGFloat = 0.9
    }

    let direction: Direction
    private let transition: FullscreenViewerTransition

    init(direction: Direction, transition: FullscreenViewerTransition) {
        self.direction = direction
        self.transition = transition
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        Animation.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        switch direction {
        case .present: present(using: transitionContext)
        case .dismiss: dismiss(using: transitionContext)
        }
    }

    // MARK: Present

    private func present(using context: UIViewControllerContextTransitioning) {
        let container = context.containerView
        guard let toVC = context.viewController(forKey: .to),
              let toView = context.view(forKey: .to) ?? toVC.view else {
            context.completeTransition(false)
            return
        }
        toView.frame = context.finalFrame(for: toVC)
        container.addSubview(toView)
        // The pages and their photos are laid out before the flight computes where it lands.
        toView.layoutIfNeeded()

        let viewer = toVC as? FullscreenImageViewerController
        let viewerImage = viewer?.currentImageForTransition
        guard let viewer, !transition.isReduceMotionEnabled(),
              let image = transition.sourceImage ?? viewerImage,
              let source = usableFrame(transition.sourceFrame, in: container) else {
            crossFadeIn(toView, using: context)
            return
        }

        let landingInViewer = HeroGeometry.fitFrame(imageSize: (viewerImage ?? image).size, in: toView.bounds)
        let landing = container.convert(landingInViewer, from: toView)
        let snapshot = FullscreenViewerHeroSnapshot(image: image, finalImage: viewerImage)
        snapshot.frame = source
        snapshot.layer.cornerRadius = transition.sourceCornerRadius
        container.addSubview(snapshot)
        // The snapshot stands for the photo during the flight.
        viewer.pager.isHidden = true
        viewer.backdropView.alpha = 0
        viewer.chromeContainer.alpha = 0

        transition.runAnimation(Animation.duration, {
            snapshot.frame = landing
            snapshot.layer.cornerRadius = 0
            snapshot.showFinalImage()
            viewer.backdropView.alpha = 1
            viewer.chromeContainer.alpha = 1
        }, { _ in
            viewer.pager.isHidden = false
            snapshot.removeFromSuperview()
            context.completeTransition(!context.transitionWasCancelled)
        })
    }

    private func crossFadeIn(_ toView: UIView, using context: UIViewControllerContextTransitioning) {
        toView.alpha = 0
        transition.runAnimation(Animation.duration, {
            toView.alpha = 1
        }, { _ in
            context.completeTransition(!context.transitionWasCancelled)
        })
    }

    // MARK: Dismiss

    private func dismiss(using context: UIViewControllerContextTransitioning) {
        let container = context.containerView
        guard let fromVC = context.viewController(forKey: .from),
              let fromView = context.view(forKey: .from) ?? fromVC.view else {
            context.completeTransition(false)
            return
        }
        // An `.overFullScreen` presenter stays in place and is not handed over; another style hands it.
        if let toVC = context.viewController(forKey: .to), let toView = context.view(forKey: .to) {
            toView.frame = context.finalFrame(for: toVC)
            container.insertSubview(toView, belowSubview: fromView)
        }

        let viewer = fromVC as? FullscreenImageViewerController
        // Read now rather than when the viewer opened: the source may have moved meanwhile.
        guard let viewer, !transition.isReduceMotionEnabled(),
              let image = viewer.currentImageForTransition,
              let startInWindow = viewer.currentImageFrameInWindow,
              let destination = usableFrame(transition.dismissSourceFrame(), in: container) else {
            fadeOut(fromView, viewer: viewer, using: context)
            return
        }

        // The photo leaves from where it is, dragged or zoomed.
        let snapshot = FullscreenViewerHeroSnapshot(image: image, finalImage: nil)
        snapshot.frame = container.convert(startInWindow, from: nil)
        snapshot.layer.cornerRadius = 0
        container.addSubview(snapshot)
        viewer.pager.isHidden = true

        transition.runAnimation(Animation.duration, { [transition] in
            snapshot.frame = destination
            snapshot.layer.cornerRadius = transition.sourceCornerRadius
            viewer.backdropView.alpha = 0
            viewer.chromeContainer.alpha = 0
        }, { _ in
            snapshot.removeFromSuperview()
            viewer.pager.isHidden = false
            Self.finishDismissal(of: fromView, using: context)
        })
    }

    private func fadeOut(_ fromView: UIView, viewer: FullscreenImageViewerController?,
                         using context: UIViewControllerContextTransitioning) {
        transition.dismissalWillFade()
        // With reduced motion, the viewer only fades: the photo does not shrink.
        let pageView = transition.isReduceMotionEnabled() ? nil : viewer.flatMap { viewer in
            viewer.pageViews.indices.contains(viewer.currentIndex) ? viewer.pageViews[viewer.currentIndex] : nil
        }
        transition.runAnimation(Animation.duration, {
            fromView.alpha = 0
            // Around the photo's own centre, wherever the drag left it.
            if let pageView {
                pageView.transform = pageView.transform.scaledBy(
                    x: Animation.fadingDismissScale, y: Animation.fadingDismissScale)
            }
        }, { _ in
            Self.finishDismissal(of: fromView, using: context)
        })
    }

    private static func finishDismissal(of fromView: UIView, using context: UIViewControllerContextTransitioning) {
        let didComplete = !context.transitionWasCancelled
        if didComplete {
            fromView.removeFromSuperview()
        }
        context.completeTransition(didComplete)
    }

    // MARK: Geometry

    /// The source frame, given in window coordinates, in the container's, when the photo can fly from or to it.
    private func usableFrame(_ frameInWindow: CGRect?, in container: UIView) -> CGRect? {
        let windowBounds = container.window?.bounds ?? container.bounds
        return HeroGeometry.usableSourceFrame(frameInWindow, in: windowBounds)
            .map { container.convert($0, from: nil) }
    }
}
