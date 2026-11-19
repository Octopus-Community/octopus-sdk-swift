//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit
import Testing
import Octopus
@testable import OctopusUI

/// The flight of a photo between its place on screen and the fullscreen viewer.
///
/// The transitions run in a 300 × 600 window, through a fake transition context, and their animations are recorded
/// rather than played: the state before the animation block, inside it, and after the completion. The viewer's
/// photo is 400 × 200: it fits at 300 × 150, centred vertically.
@MainActor
struct FullscreenViewerTransitionTests {
    private static let window = CGRect(x: 0, y: 0, width: 300, height: 600)
    private static let fitFrame = CGRect(x: 0, y: 225, width: 300, height: 150)
    private static let sourceFrame = CGRect(x: 20, y: 100, width: 120, height: 120)

    // MARK: Geometry

    @Test(arguments: [
        nil,
        CGRect.zero,
        // 30 of its 300 points of width are in the window: 10 % of its area.
        CGRect(x: -270, y: 100, width: 300, height: 100),
        // 25 % of its area is in the window.
        CGRect(x: 150, y: 550, width: 300, height: 100),
        CGRect(x: 400, y: 100, width: 100, height: 100),
    ] as [CGRect?])
    func fallsBackToFadeWithoutUsableSourceFrame(frame: CGRect?) {
        #expect(HeroGeometry.usableSourceFrame(frame, in: Self.window) == nil)
    }

    @Test(arguments: [
        CGRect(x: 20, y: 100, width: 120, height: 120),
        // Half of it is in the window.
        CGRect(x: -150, y: 100, width: 300, height: 100),
        // 35 % of it is in the window.
        CGRect(x: 150, y: 530, width: 300, height: 100),
    ])
    func keepsAMostlyVisibleFrame(frame: CGRect) {
        // The frame is kept whole, not clipped to the window: the photo flies to where it is.
        #expect(HeroGeometry.usableSourceFrame(frame, in: Self.window) == frame)
    }

    @Test func fitFrameCentresALandscapePhoto() {
        #expect(HeroGeometry.fitFrame(imageSize: CGSize(width: 2000, height: 1000),
                                      in: CGRect(x: 0, y: 0, width: 400, height: 800))
                == CGRect(x: 0, y: 300, width: 400, height: 200))
        // Bounds that do not start at the origin.
        #expect(HeroGeometry.fitFrame(imageSize: CGSize(width: 2000, height: 1000),
                                      in: CGRect(x: 10, y: 20, width: 400, height: 800))
                == CGRect(x: 10, y: 320, width: 400, height: 200))
    }

    @Test func fitFrameCentresAPortraitPhoto() {
        #expect(HeroGeometry.fitFrame(imageSize: CGSize(width: 1000, height: 4000),
                                      in: CGRect(x: 0, y: 0, width: 400, height: 800))
                == CGRect(x: 100, y: 0, width: 200, height: 800))
    }

    // MARK: Present

    @Test func heroKeepsTheSourceCornerRadius() throws {
        let sourceImage = makeImage(size: CGSize(width: 120, height: 120))
        let stage = makeStage()
        defer { stage.window.isHidden = true }
        let viewer = makeViewer()
        let transition = FullscreenViewerTransition(
            sourceFrame: Self.sourceFrame, sourceCornerRadius: 20, sourceImage: sourceImage)
        let recorder = FlightRecorder(container: stage.container, viewer: viewer)
        transition.runAnimation = recorder.run
        let context = FakeTransitionContext(container: stage.container, presented: viewer, isPresenting: true)

        let animator = try #require(transition.animationController(
            forPresented: viewer, presenting: stage.presenter, source: stage.presenter))
        #expect(animator.transitionDuration(using: context) == 0.3)
        animator.animateTransition(using: context)

        let before = try #require(recorder.before)
        #expect(before.snapshotFrame == Self.sourceFrame)
        #expect(before.cornerRadius == 20)
        #expect(before.snapshotImage === sourceImage)
        #expect(before.snapshotFillsAndClips)
        #expect(before.backdropAlpha == 0)
        // The real page only shows once the snapshot has landed: the photo is never shown twice.
        #expect(before.pagerHidden)

        let during = try #require(recorder.during)
        #expect(during.snapshotFrame == Self.fitFrame)
        #expect(during.cornerRadius == 0)
        #expect(during.backdropAlpha == 1)
        #expect(during.chromeAlpha == 1)
        // The viewer's own photo fades in over the source's crop, so that the landing does not jump.
        #expect(during.finalImageAlpha == 1)
        #expect(recorder.durations == [0.3])

        recorder.finish()
        #expect(snapshot(in: stage.container) == nil)
        #expect(!viewer.pager.isHidden)
        #expect(viewer.view.superview === stage.container)
        #expect(context.completions == [true])
    }

    @Test func heroUsesTheViewerPhotoWithoutASourceImage() throws {
        let stage = makeStage()
        defer { stage.window.isHidden = true }
        let viewer = makeViewer()
        let transition = FullscreenViewerTransition(
            sourceFrame: Self.sourceFrame, sourceCornerRadius: 60, sourceImage: nil)
        let recorder = FlightRecorder(container: stage.container, viewer: viewer)
        transition.runAnimation = recorder.run
        let context = FakeTransitionContext(container: stage.container, presented: viewer, isPresenting: true)

        try present(transition, viewer: viewer, stage: stage, context: context)

        let before = try #require(recorder.before)
        #expect(before.snapshotImage === viewer.items[0].image)
        #expect(before.cornerRadius == 60)
        #expect(before.finalImageAlpha == nil)
        #expect(recorder.during?.snapshotFrame == Self.fitFrame)
    }

    @Test func presentCrossFadesWithoutUsableSourceFrame() throws {
        let stage = makeStage()
        defer { stage.window.isHidden = true }
        let viewer = makeViewer()
        let transition = FullscreenViewerTransition(
            sourceFrame: CGRect(x: 400, y: 100, width: 100, height: 100), sourceCornerRadius: 20,
            sourceImage: makeImage(size: CGSize(width: 100, height: 100)))
        let recorder = FlightRecorder(container: stage.container, viewer: viewer)
        transition.runAnimation = recorder.run
        let context = FakeTransitionContext(container: stage.container, presented: viewer, isPresenting: true)

        try present(transition, viewer: viewer, stage: stage, context: context)

        let before = try #require(recorder.before)
        #expect(before.snapshotFrame == nil)
        #expect(before.viewAlpha == 0)
        #expect(!before.pagerHidden)
        #expect(recorder.during?.viewAlpha == 1)

        recorder.finish()
        #expect(context.completions == [true])
    }

    @Test func reduceMotionCrossFades() throws {
        let stage = makeStage()
        defer { stage.window.isHidden = true }
        let viewer = makeViewer()
        let transition = FullscreenViewerTransition(
            sourceFrame: Self.sourceFrame, sourceCornerRadius: 20,
            sourceImage: makeImage(size: CGSize(width: 120, height: 120)))
        transition.isReduceMotionEnabled = { true }
        let recorder = FlightRecorder(container: stage.container, viewer: viewer)
        transition.runAnimation = recorder.run
        let context = FakeTransitionContext(container: stage.container, presented: viewer, isPresenting: true)

        try present(transition, viewer: viewer, stage: stage, context: context)

        #expect(recorder.before?.snapshotFrame == nil)
        #expect(recorder.before?.viewAlpha == 0)
        #expect(recorder.during?.viewAlpha == 1)
    }

    // MARK: Dismiss

    @Test func dismissFliesBackFromTheDraggedPhotoToTheUpdatedSource() throws {
        let stage = makeStage()
        defer { stage.window.isHidden = true }
        let viewer = makeViewer()
        showInStage(viewer, stage: stage)
        let transition = FullscreenViewerTransition(
            sourceFrame: Self.sourceFrame, sourceCornerRadius: 20, sourceImage: nil)
        // The carousel was synced to the photo shown: it is somewhere else now.
        let updatedSource = CGRect(x: 40, y: 50, width: 100, height: 100)
        transition.dismissSourceFrame = { updatedSource }
        let recorder = FlightRecorder(container: stage.container, viewer: viewer)
        transition.runAnimation = recorder.run
        let context = FakeTransitionContext(container: stage.container, presented: viewer, isPresenting: false)
        viewer.dragToDismiss(translation: CGPoint(x: 10, y: 100))

        let fades = Calls()
        transition.dismissalWillFade = { fades.times += 1 }

        let animator = try #require(transition.animationController(forDismissed: viewer))
        animator.animateTransition(using: context)

        // The photo flies to the source: the screen gets it back when it lands, not before.
        #expect(fades.times == 0)
        let before = try #require(recorder.before)
        #expect(isClose(try #require(before.snapshotFrame), CGRect(x: 10, y: 325, width: 300, height: 150)))
        #expect(before.cornerRadius == 0)
        #expect(before.snapshotImage === viewer.items[0].image)
        #expect(before.snapshotFillsAndClips)
        #expect(before.pagerHidden)

        let during = try #require(recorder.during)
        #expect(during.snapshotFrame == updatedSource)
        #expect(during.cornerRadius == 20)
        #expect(during.backdropAlpha == 0)
        #expect(during.chromeAlpha == 0)

        recorder.finish()
        #expect(snapshot(in: stage.container) == nil)
        #expect(viewer.view.superview == nil)
        #expect(context.completions == [true])
    }

    @Test func dismissFadesWhenTheSourceIsGone() throws {
        let stage = makeStage()
        defer { stage.window.isHidden = true }
        let viewer = makeViewer()
        showInStage(viewer, stage: stage)
        let transition = FullscreenViewerTransition(
            sourceFrame: Self.sourceFrame, sourceCornerRadius: 20, sourceImage: nil)
        // The feed refreshed while the viewer was shown: the source is no longer on screen.
        transition.dismissSourceFrame = { CGRect(x: 0, y: -500, width: 100, height: 100) }
        let recorder = FlightRecorder(container: stage.container, viewer: viewer)
        transition.runAnimation = recorder.run
        let context = FakeTransitionContext(container: stage.container, presented: viewer, isPresenting: false)

        let fades = Calls()
        transition.dismissalWillFade = { fades.times += 1 }

        let animator = try #require(transition.animationController(forDismissed: viewer))
        animator.animateTransition(using: context)

        // Nothing flies to the source: it is given back as the fade starts, not once it ends.
        #expect(fades.times == 1)
        #expect(context.completions.isEmpty)
        #expect(recorder.before?.snapshotFrame == nil)
        let during = try #require(recorder.during)
        #expect(during.viewAlpha == 0)
        // The photo shrinks slightly as it fades.
        let transform = viewer.pageViews[0].transform
        #expect(isClose(transform.a, 0.9))
        #expect(isClose(transform.d, 0.9))

        recorder.finish()
        #expect(viewer.view.superview == nil)
        #expect(context.completions == [true])
    }

    @Test func reduceMotionDismissalOnlyFades() throws {
        let stage = makeStage()
        defer { stage.window.isHidden = true }
        let viewer = makeViewer()
        showInStage(viewer, stage: stage)
        let transition = FullscreenViewerTransition(
            sourceFrame: Self.sourceFrame, sourceCornerRadius: 20, sourceImage: nil)
        transition.isReduceMotionEnabled = { true }
        let recorder = FlightRecorder(container: stage.container, viewer: viewer)
        transition.runAnimation = recorder.run
        let context = FakeTransitionContext(container: stage.container, presented: viewer, isPresenting: false)
        // Left where the drag put it.
        viewer.dragToDismiss(translation: CGPoint(x: 0, y: 40))
        let draggedTransform = viewer.pageViews[0].transform
        let fades = Calls()
        transition.dismissalWillFade = { fades.times += 1 }

        let animator = try #require(transition.animationController(forDismissed: viewer))
        animator.animateTransition(using: context)

        #expect(fades.times == 1)
        #expect(context.completions.isEmpty)
        // No flight, and no shrink.
        #expect(recorder.before?.snapshotFrame == nil)
        #expect(recorder.during?.viewAlpha == 0)
        #expect(viewer.pageViews[0].transform == draggedTransform)

        recorder.finish()
        #expect(context.completions == [true])
    }

    @Test func dismissStartsFromTheInitialSourceByDefault() throws {
        let transition = FullscreenViewerTransition(
            sourceFrame: Self.sourceFrame, sourceCornerRadius: 20, sourceImage: nil)
        #expect(transition.dismissSourceFrame() == Self.sourceFrame)
    }

    // MARK: Helpers

    private func present(_ transition: FullscreenViewerTransition, viewer: FullscreenImageViewerController,
                         stage: Stage, context: FakeTransitionContext) throws {
        let animator = try #require(transition.animationController(
            forPresented: viewer, presenting: stage.presenter, source: stage.presenter))
        animator.animateTransition(using: context)
    }

    private func makeStage() -> Stage {
        // The test host runs without scenes, so the window is attached to the screen directly.
        let window = UIWindow(frame: Self.window)
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        let container = UIView(frame: window.bounds)
        window.addSubview(container)
        return Stage(window: window, presenter: presenter, container: container)
    }

    private func makeViewer() -> FullscreenImageViewerController {
        let items = [ZoomableImageInfo.Item(
            url: URL(fileURLWithPath: "/nonexistent/transition-\(UUID().uuidString).jpg"),
            image: makeImage(size: CGSize(width: 400, height: 200)),
            transitionImage: nil)]
        return FullscreenImageViewerController(
            info: ZoomableImageInfo(items: items, index: 0, sourceFrame: Self.sourceFrame),
            theme: OctopusTheme(),
            locale: Locale(identifier: "en"),
            imageLoaders: CarouselImageLoaders(makeLoader: {
                AsyncCachedImageLoader($0, cache: .content, croppingRatio: nil)
            }),
            onClose: { _ in })
    }

    /// Puts the viewer on screen as it is once presented.
    private func showInStage(_ viewer: FullscreenImageViewerController, stage: Stage) {
        viewer.view.frame = stage.container.bounds
        stage.container.addSubview(viewer.view)
        viewer.view.layoutIfNeeded()
    }
}

@MainActor
private struct Stage {
    let window: UIWindow
    let presenter: UIViewController
    let container: UIView
}

@MainActor
private func snapshot(in container: UIView) -> FullscreenViewerHeroSnapshot? {
    container.subviews.lazy.compactMap { $0 as? FullscreenViewerHeroSnapshot }.first
}

@MainActor
private final class Calls {
    var times = 0
}

/// Plays the animations of a transition synchronously, recording the state around them, and keeps the completion
/// until `finish()`.
@MainActor
private final class FlightRecorder {
    struct State {
        let snapshotFrame: CGRect?
        let cornerRadius: CGFloat?
        let snapshotImage: UIImage?
        let snapshotFillsAndClips: Bool
        let finalImageAlpha: CGFloat?
        let backdropAlpha: CGFloat
        let chromeAlpha: CGFloat
        let pagerHidden: Bool
        let viewAlpha: CGFloat
    }

    private let container: UIView
    private let viewer: FullscreenImageViewerController
    private(set) var before: State?
    private(set) var during: State?
    private(set) var durations: [TimeInterval] = []
    private var completion: ((Bool) -> Void)?

    init(container: UIView, viewer: FullscreenImageViewerController) {
        self.container = container
        self.viewer = viewer
    }

    var run: FullscreenViewerTransition.AnimationRunner {
        { [self] duration, animations, completion in
            durations.append(duration)
            before = capture()
            animations()
            during = capture()
            self.completion = completion
        }
    }

    func finish() {
        completion?(true)
        completion = nil
    }

    private func capture() -> State {
        let snapshot = snapshot(in: container)
        return State(
            snapshotFrame: snapshot?.frame,
            cornerRadius: snapshot?.layer.cornerRadius,
            snapshotImage: snapshot?.imageView.image,
            snapshotFillsAndClips: snapshot.map {
                $0.clipsToBounds && $0.imageView.contentMode == .scaleAspectFill
            } ?? false,
            finalImageAlpha: snapshot?.finalImageView?.alpha,
            backdropAlpha: viewer.backdropView.alpha,
            chromeAlpha: viewer.chromeContainer.alpha,
            pagerHidden: viewer.pager.isHidden,
            viewAlpha: viewer.view.alpha)
    }
}

/// A transition context for an `.overFullScreen` presentation of `presented`: the presenter's view stays in place,
/// so only the presented view is handed over.
@MainActor
private final class FakeTransitionContext: NSObject, UIViewControllerContextTransitioning {
    let containerView: UIView
    private let presented: UIViewController
    private let isPresenting: Bool
    private(set) var completions: [Bool] = []

    init(container: UIView, presented: UIViewController, isPresenting: Bool) {
        containerView = container
        self.presented = presented
        self.isPresenting = isPresenting
    }

    var isAnimated: Bool { true }
    var isInteractive: Bool { false }
    var transitionWasCancelled: Bool { false }
    var presentationStyle: UIModalPresentationStyle { .overFullScreen }
    var targetTransform: CGAffineTransform { .identity }

    func updateInteractiveTransition(_ percentComplete: CGFloat) {}
    func finishInteractiveTransition() {}
    func cancelInteractiveTransition() {}
    func pauseInteractiveTransition() {}

    func completeTransition(_ didComplete: Bool) {
        completions.append(didComplete)
    }

    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        (key == .to) == isPresenting ? presented : nil
    }

    func view(forKey key: UITransitionContextViewKey) -> UIView? {
        (key == .to) == isPresenting ? presented.view : nil
    }

    func initialFrame(for viewController: UIViewController) -> CGRect {
        viewController === presented && !isPresenting ? containerView.bounds : .zero
    }

    func finalFrame(for viewController: UIViewController) -> CGRect {
        viewController === presented && isPresenting ? containerView.bounds : .zero
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

private func isClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    isClose(lhs.minX, rhs.minX) && isClose(lhs.minY, rhs.minY)
        && isClose(lhs.width, rhs.width) && isClose(lhs.height, rhs.height)
}
