//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import Testing
import UIKit
import Octopus
@testable import OctopusUI

/// How a screen presents the fullscreen viewer for its requests, and gets them back. The viewers run in a 300 × 600
/// window. The test host has no scene for a UIKit presentation to run in: a fake one stands for it, whose transitions
/// end when the test says so.
@MainActor
struct FullscreenViewerPresentationTests {
    @Test func dismissReportsTheFinalIndex() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        let request = makeRequest(count: 6, index: 2, onDismiss: { index in
            log.entries.append("onDismiss(\(index)) flying back: \(stage.uiKit.dismissCompletion != nil)")
        })

        presentation.update(request: request, anchor: stage.anchor, theme: OctopusTheme(), locale: nil)
        let viewer = try #require(presentation.viewer)
        #expect(stage.uiKit.presented === viewer)
        #expect(stage.uiKit.presenter === stage.root)
        #expect(viewer.currentIndex == 2)
        // Kept alive by the presentation: the viewer only holds it weakly.
        #expect(viewer.transitioningDelegate === presentation.transition)
        stage.uiKit.finishPresentation()
        #expect(presentation.phase == .presented)

        viewer.pager.contentOffset.x = 5 * viewer.pager.bounds.width
        #expect(viewer.currentIndex == 5)
        #expect(viewer.accessibilityPerformEscape())
        // Called before the photo flies back, and the request is still there.
        #expect(log.entries == ["onDismiss(5) flying back: false"])
        #expect(stage.uiKit.dismissAnimated == true)
        #expect(presentation.phase == .dismissing)

        stage.uiKit.finishDismissal()
        #expect(log.entries == ["onDismiss(5) flying back: false", "cleared"])
        #expect(presentation.viewer == nil)
        #expect(presentation.transition == nil)
        #expect(presentation.phase == .idle)
    }

    @Test func bindingNilDismissesTheViewer() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        let request = makeRequest(count: 3, index: 0, onDismiss: { log.entries.append("onDismiss(\($0))") })
        presentation.update(request: request, anchor: stage.anchor, theme: OctopusTheme(), locale: nil)
        let viewer = try #require(presentation.viewer)
        stage.uiKit.finishPresentation()
        viewer.pager.contentOffset.x = 2 * viewer.pager.bounds.width

        presentation.update(request: nil, anchor: stage.anchor, theme: OctopusTheme(), locale: nil)
        #expect(log.entries == ["onDismiss(2)"])
        #expect(stage.uiKit.dismissAnimated == true)
        // The update that follows the dismissal changes nothing.
        presentation.update(request: nil, anchor: stage.anchor, theme: OctopusTheme(), locale: nil)
        #expect(log.entries == ["onDismiss(2)"])

        stage.uiKit.finishDismissal()
        #expect(log.entries == ["onDismiss(2)", "cleared"])
        #expect(presentation.viewer == nil)
    }

    /// The screens keep their request in a state that only the source reads: setting it from the source must still
    /// reach the presenter, which only gets a binding to it.
    @Test func screenPresentsForItsRequestAndGetsItBack() async throws {
        let source = SourceDriver()
        let log = Log()
        // The test host runs without scenes, so the window is attached to the screen directly.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        let uiKit = FakeUIKit(window: window)
        let host = UIHostingController(rootView: PresentingScreen(
            source: source, factory: PresentationFactory(uiKit: uiKit)))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await waitUntil { source.shownRequest == .some(nil) }

        // The source sets the request: the viewer opens.
        source.tap.send(makeRequest(count: 3, index: 1, onDismiss: { log.entries.append("onDismiss(\($0))") }))
        try await waitUntil { uiKit.presentations == 1 }
        #expect(uiKit.presenter === host)
        let viewer = try #require(uiKit.presented as? FullscreenImageViewerController)
        uiKit.finishPresentation()

        // Closing it gives the request back, once the photo has landed.
        #expect(viewer.accessibilityPerformEscape())
        #expect(log.entries == ["onDismiss(1)"])
        #expect(source.shownRequest??.index == 1)
        uiKit.finishDismissal()
        try await waitUntil { source.shownRequest == .some(nil) }

        // Clearing the request closes the viewer.
        source.tap.send(makeRequest(count: 3, index: 2, onDismiss: { log.entries.append("onDismiss(\($0))") }))
        try await waitUntil { uiKit.presentations == 2 }
        uiKit.finishPresentation()
        source.tap.send(nil)
        try await waitUntil { log.entries.count == 2 }
        #expect(log.entries == ["onDismiss(1)", "onDismiss(2)"])
        #expect(uiKit.dismissAnimated == true)
        uiKit.finishDismissal()
    }

    @Test func closeDuringThePresentationWaitsForItsEnd() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        let request = makeRequest(count: 3, index: 1, onDismiss: { log.entries.append("onDismiss(\($0))") })

        presentation.update(request: request, anchor: stage.anchor, theme: OctopusTheme(), locale: nil)
        let viewer = try #require(presentation.viewer)
        #expect(presentation.phase == .presenting)
        #expect(viewer.accessibilityPerformEscape())
        // UIKit cannot dismiss a controller still being presented.
        #expect(log.entries.isEmpty)
        #expect(stage.uiKit.dismissAnimated == nil)

        stage.uiKit.finishPresentation()
        #expect(log.entries == ["onDismiss(1)"])
        #expect(stage.uiKit.dismissAnimated == true)
        stage.uiKit.finishDismissal()
        #expect(log.entries == ["onDismiss(1)", "cleared"])
    }

    @Test func newRequestWhileShownIsIgnored() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let presentation = stage.makePresentation(log: Log())
        presentation.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)
        let viewer = try #require(presentation.viewer)
        stage.uiKit.finishPresentation()

        presentation.update(request: makeRequest(count: 4, index: 3), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)

        #expect(presentation.viewer === viewer)
        #expect(stage.uiKit.presentations == 1)
    }

    @Test func refusedPresentationGivesTheRequestBack() {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        stage.uiKit.intake = .refused

        presentation.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)
        // Not taken for refused before the transitions in progress are over.
        #expect(presentation.viewer != nil)
        #expect(log.entries.isEmpty)

        stage.uiKit.endPendingTransitions()
        #expect(presentation.viewer == nil)
        #expect(presentation.transition == nil)
        #expect(presentation.phase == .idle)
        #expect(log.entries == ["cleared"])
    }

    /// The wait for the transitions in progress, as UIKit runs it.
    @Test(arguments: [CoordinatorAnswer.none, .refusesTheCompletion, .keepsTheCompletion])
    func pendingTransitionsAlwaysEnd(answer: CoordinatorAnswer) async throws {
        let presenter = CoordinatedController()
        let coordinator = FakeTransitionCoordinator(acceptsCompletion: answer == .keepsTheCompletion)
        presenter.coordinator = answer == .none ? nil : coordinator
        let presentation = FullscreenViewerPresentation()
        var runs = 0

        presentation.afterPendingTransitions(presenter) { runs += 1 }

        if answer == .keepsTheCompletion {
            // Only once the transition is over.
            try await Task.sleep(nanoseconds: 100_000_000)
            #expect(runs == 0)
            coordinator.endTransition()
        }
        // A refused completion is never called: the action must not wait for it.
        try await waitUntil { runs == 1 }
        #expect(runs == 1)
    }

    /// UIKit can hold a presentation asked for during a navigation push until the push ends.
    @Test func delayedPresentationKeepsItsOwner() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        stage.uiKit.intake = .delayed
        let request = makeRequest(count: 2, index: 1, onDismiss: { log.entries.append("onDismiss(\($0))") })

        presentation.update(request: request, anchor: stage.anchor, theme: OctopusTheme(), locale: nil)
        let viewer = try #require(presentation.viewer)
        stage.uiKit.endPendingTransitions()

        #expect(presentation.viewer === viewer)
        #expect(viewer.transitioningDelegate === presentation.transition)
        #expect(log.entries.isEmpty)
        stage.uiKit.finishPresentation()
        #expect(presentation.phase == .presented)
        // It can be closed.
        #expect(viewer.accessibilityPerformEscape())
        #expect(log.entries == ["onDismiss(1)"])
        stage.uiKit.finishDismissal()
        #expect(log.entries == ["onDismiss(1)", "cleared"])
    }

    @Test func viewerShownAfterARefusalGoesAway() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        stage.uiKit.intake = .refused
        presentation.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)
        stage.uiKit.endPendingTransitions()
        #expect(log.entries == ["cleared"])

        // UIKit shows it anyway, later.
        stage.uiKit.finishPresentation()

        #expect(stage.uiKit.dismissals == 1)
        #expect(stage.uiKit.dismissAnimated == false)
        #expect(presentation.phase == .idle)
        #expect(log.entries == ["cleared"])
    }

    @Test func dismissFliesBackToTheSourceWhereItIsNow() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let presentation = stage.makePresentation(log: Log())
        // The anchor fills the window: the global space is the window's.
        presentation.anchorGlobalFrame = { CGRect(x: 0, y: 0, width: 300, height: 600) }
        let source = MovingSource(frame: CGRect(x: 0, y: 100, width: 300, height: 200))
        let item = ZoomableImageInfo.Item(
            url: URL(fileURLWithPath: "/nonexistent/moving.jpg"), image: makeImage(), transitionImage: nil)
        let request = ZoomableImageInfo(
            items: [item], index: 0, sourceFrame: source.frame, liveSourceFrame: { source.frame })

        presentation.update(request: request, anchor: stage.anchor, theme: OctopusTheme(), locale: nil)
        stage.uiKit.finishPresentation()
        let transition = try #require(presentation.transition)
        #expect(transition.sourceFrame == CGRect(x: 0, y: 100, width: 300, height: 200))

        // A rotation, or a change of the layout above the source.
        source.frame = CGRect(x: 0, y: 250, width: 300, height: 200)
        #expect(transition.dismissSourceFrame() == CGRect(x: 0, y: 250, width: 300, height: 200))
        // Gone from the screen: the viewer fades.
        source.frame = nil
        #expect(transition.dismissSourceFrame() == nil)
    }

    @Test func everyOwnerOfARequestPresentsTheViewer() throws {
        // The sources of the SDK, next to the tests.
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/OctopusUI")
        let files = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var owners: [String] = []
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            guard text.contains("@State private var zoomableImageInfo: ZoomableImageInfo?") else { continue }
            owners.append(file.lastPathComponent)
            // A request no presenter reads hides the photo tapped, and opens nothing.
            #expect(text.contains(".zoomableImageContainer(") || text.contains(".fullscreenImageViewer("),
                    "\(file.lastPathComponent) owns a photo request but presents no viewer")
        }
        #expect(owners.count == 7)
    }

    @Test func emptyRequestIsGivenBack() {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)

        presentation.update(
            request: ZoomableImageInfo(items: [], index: 0, sourceFrame: nil), anchor: stage.anchor,
            theme: OctopusTheme(), locale: nil)

        #expect(presentation.viewer == nil)
        #expect(stage.uiKit.presentations == 0)
        #expect(log.entries == ["cleared"])
    }

    @Test func anchorLeavingTheScreenTakesTheViewerAway() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        presentation.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)
        stage.uiKit.finishPresentation()

        presentation.anchorDidDisappear()

        #expect(stage.uiKit.dismissAnimated == false)
        stage.uiKit.finishDismissal()
        #expect(presentation.viewer == nil)
        #expect(presentation.phase == .idle)
        // The screen is gone: nothing to give back to it.
        #expect(log.entries.isEmpty)
    }

    /// The screen leaves during the opening flight (a post detail that pops itself, a session change): UIKit cannot
    /// dismiss the viewer yet, and SwiftUI releases the presentation with the screen.
    @Test func anchorLeavingDuringThePresentationTakesTheViewerAwayOnceShown() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        var presentation: FullscreenViewerPresentation? = stage.makePresentation(log: log)
        weak let releasedPresentation = presentation
        presentation?.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                             locale: nil)
        #expect(presentation?.phase == .presenting)

        presentation?.anchorDidDisappear()
        #expect(stage.uiKit.dismissals == 0)
        presentation = nil
        // Kept until the viewer is shown, the only moment it can take it away.
        #expect(releasedPresentation != nil)

        stage.uiKit.finishPresentation()
        #expect(stage.uiKit.dismissals == 1)
        #expect(stage.uiKit.dismissAnimated == false)
        stage.uiKit.finishDismissal()
        #expect(releasedPresentation == nil)
        // The screen is gone: nothing to give back to it.
        #expect(log.entries.isEmpty)
    }

    @Test func anchorLeavingBeforeARefusedPresentationGivesNothingBack() {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        stage.uiKit.intake = .refused
        presentation.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)

        presentation.anchorDidDisappear()
        stage.uiKit.endPendingTransitions()

        #expect(presentation.viewer == nil)
        #expect(presentation.phase == .idle)
        #expect(log.entries.isEmpty)
    }

    @Test func fadingDismissalGivesTheSourceBackWhenTheFadeStarts() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        presentation.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)
        stage.uiKit.finishPresentation()
        let transition = try #require(presentation.transition)
        // Before the viewer closes there is no fade.
        transition.dismissalWillFade()
        #expect(log.entries.isEmpty)

        let viewer = try #require(presentation.viewer)
        #expect(viewer.accessibilityPerformEscape())
        #expect(presentation.phase == .dismissing)
        // The transition fades: nothing flies to the source, which comes back before the fade ends.
        transition.dismissalWillFade()
        #expect(log.entries == ["cleared"])
        #expect(presentation.viewer != nil)

        stage.uiKit.finishDismissal()
        #expect(presentation.viewer == nil)
        #expect(presentation.phase == .idle)
    }

    @Test func anchorLeavingTheScreenDoesNotGiveTheSourceBackWhenTheViewerFades() throws {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        let log = Log()
        let presentation = stage.makePresentation(log: log)
        presentation.update(request: makeRequest(count: 2, index: 0), anchor: stage.anchor, theme: OctopusTheme(),
                            locale: nil)
        stage.uiKit.finishPresentation()
        let transition = try #require(presentation.transition)

        presentation.anchorDidDisappear()
        transition.dismissalWillFade()

        // The screen is gone: nothing to give back to it.
        #expect(log.entries.isEmpty)
        stage.uiKit.finishDismissal()
    }

    @Test func presentsFromTheTopmostController() {
        let stage = Stage()
        defer { stage.window.isHidden = true }
        #expect(FullscreenViewerPresentation.presenter(for: stage.anchor) === stage.root)

        let sheet = UIViewController()
        stage.root.present(sheet, animated: false)
        #expect(FullscreenViewerPresentation.presenter(for: stage.anchor) === sheet)

        // An anchor out of the screen cannot present anything.
        #expect(FullscreenViewerPresentation.presenter(for: UIViewController()) == nil)
    }

    @Test func sourceFrameIsBroughtToTheWindow() {
        let source = CGRect(x: 10, y: 20, width: 100, height: 50)
        // A screen filling its window: the global space is the window's.
        #expect(FullscreenViewerPresentation.windowFrame(
            of: source, anchorGlobalFrame: CGRect(x: 0, y: 0, width: 300, height: 600),
            anchorWindowFrame: CGRect(x: 0, y: 0, width: 300, height: 600)) == source)
        // A sheet, whose hosting view starts lower in the window.
        #expect(FullscreenViewerPresentation.windowFrame(
            of: source, anchorGlobalFrame: CGRect(x: 0, y: 0, width: 300, height: 540),
            anchorWindowFrame: CGRect(x: 0, y: 60, width: 300, height: 540))
                == CGRect(x: 10, y: 80, width: 100, height: 50))
        #expect(FullscreenViewerPresentation.windowFrame(
            of: nil, anchorGlobalFrame: .zero, anchorWindowFrame: .zero) == nil)
        #expect(FullscreenViewerPresentation.windowFrame(
            of: source, anchorGlobalFrame: nil, anchorWindowFrame: CGRect(x: 0, y: 60, width: 1, height: 1))
                == source)
    }

    @Test func sourceFrameInAnOffsetScreenIsInTheWindow() async throws {
        let model = RequestModel()
        let probe = Probe()
        // The test host runs without scenes, so the window is attached to the screen directly.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        // A hosting view that does not start at the top of the window, as in a sheet. A real sheet is not laid out
        // in this scene-less test host.
        let screen = UIHostingController(rootView: SourceScreen(model: model, probe: probe))
        root.addChild(screen)
        screen.view.frame = CGRect(x: 0, y: 60, width: 390, height: 784)
        root.view.addSubview(screen.view)
        screen.didMove(toParent: root)
        try await waitUntil {
            guard let view = probe.view, view.window != nil, let frame = probe.geometry.frame else { return false }
            // Wait for the layout to settle.
            return frame.size == CGSize(width: 100, height: 50) && view.bounds.size == frame.size
        }
        let probeView = try #require(probe.view)
        let expected = probeView.convert(probeView.bounds, to: nil)

        model.request = makeRequest(count: 1, index: 0, sourceFrame: probe.geometry.frame)
        try await waitUntil { root.presentedViewController is FullscreenImageViewerController }
        let viewer = try #require(root.presentedViewController as? FullscreenImageViewerController)
        let transition = try #require(viewer.transitioningDelegate as? FullscreenViewerTransition)
        let sourceFrame = try #require(transition.sourceFrame)
        #expect(abs(sourceFrame.minX - expected.minX) < 0.5)
        #expect(abs(sourceFrame.minY - expected.minY) < 0.5)
        #expect(sourceFrame.size == expected.size)
    }

    // MARK: Helpers

    private func makeRequest(count: Int, index: Int,
                             sourceFrame: CGRect? = CGRect(x: 0, y: 100, width: 300, height: 200),
                             onDismiss: ((Int) -> Void)? = nil) -> ZoomableImageInfo {
        let items = (0..<count).map { offset in
            // Files that do not exist: the viewer only shows the images it is given, without any network call.
            ZoomableImageInfo.Item(
                url: URL(fileURLWithPath: "/nonexistent/presentation-\(UUID().uuidString)-\(offset).jpg"),
                image: makeImage(),
                transitionImage: nil)
        }
        return ZoomableImageInfo(items: items, index: index, sourceFrame: sourceFrame, onDismiss: onDismiss)
    }
}

/// A screen with an anchor, as `fullscreenImageViewer` installs it.
@MainActor
private struct Stage {
    let window: UIWindow
    let root: UIViewController
    let anchor: UIViewController
    let uiKit: FakeUIKit

    init() {
        // The test host runs without scenes, so the window is attached to the screen directly.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        anchor = UIViewController()
        root.addChild(anchor)
        anchor.view.frame = root.view.bounds
        root.view.addSubview(anchor.view)
        anchor.didMove(toParent: root)
        uiKit = FakeUIKit(window: window)
    }

    func makePresentation(log: Log) -> FullscreenViewerPresentation {
        let presentation = FullscreenViewerPresentation()
        presentation.clearRequest = { log.entries.append("cleared") }
        uiKit.install(on: presentation)
        return presentation
    }
}

/// Presents and dismisses like UIKit, the transitions ending when the test calls `finish…`.
@MainActor
private final class FakeUIKit {
    /// How UIKit takes in a presentation it is asked for.
    enum Intake {
        /// Presented at once.
        case immediate
        /// Held until the transition in progress ends, then presented.
        case delayed
        /// Never presented.
        case refused
    }

    let window: UIWindow
    var intake = Intake.immediate
    private(set) var presentations = 0
    private(set) weak var presented: UIViewController?
    private(set) weak var presenter: UIViewController?
    private(set) var presentCompletion: (@MainActor () -> Void)?
    private(set) var dismissCompletion: (@MainActor () -> Void)?
    private(set) var dismissAnimated: Bool?
    private(set) var dismissals = 0
    /// What waits for the end of the transitions in progress.
    private var pendingChecks: [@MainActor () -> Void] = []
    private var takenIn: Set<ObjectIdentifier> = []

    init(window: UIWindow) {
        self.window = window
    }

    func install(on presentation: FullscreenViewerPresentation) {
        // Weak: the presentation holds these closures.
        presentation.presentViewer = { [weak self] viewer, presenter, completion in
            guard let self else { return }
            presentations += 1
            self.presenter = presenter
            presentCompletion = completion
            if intake == .immediate {
                takeIn(viewer)
            } else {
                presented = viewer
            }
        }
        presentation.isViewerPresented = { [weak self] viewer in
            self?.takenIn.contains(ObjectIdentifier(viewer)) ?? false
        }
        presentation.afterPendingTransitions = { [weak self] _, action in
            self?.pendingChecks.append(action)
        }
        presentation.dismissViewer = { [weak self] viewer, animated, completion in
            self?.dismissals += 1
            self?.dismissAnimated = animated
            self?.dismissCompletion = {
                viewer.view.removeFromSuperview()
                completion()
            }
        }
    }

    /// Ends the transition in progress: a delayed presentation is taken in, then the checks waiting for it run.
    func endPendingTransitions() {
        if intake == .delayed, let presented {
            takeIn(presented)
        }
        let checks = pendingChecks
        pendingChecks = []
        checks.forEach { $0() }
    }

    func finishPresentation() {
        let completion = presentCompletion
        presentCompletion = nil
        completion?()
    }

    func finishDismissal() {
        let completion = dismissCompletion
        dismissCompletion = nil
        completion?()
    }

    private func takeIn(_ viewer: UIViewController) {
        presented = viewer
        takenIn.insert(ObjectIdentifier(viewer))
        // On screen, as once presented.
        viewer.view.frame = window.bounds
        window.addSubview(viewer.view)
        viewer.view.layoutIfNeeded()
    }
}

enum CoordinatorAnswer {
    /// No transition in progress.
    case none
    /// A transition in progress, which does not take the completion, as when it is not animated.
    case refusesTheCompletion
    /// A transition in progress, which calls the completion when it ends.
    case keepsTheCompletion
}

/// A controller during a transition, whose coordinator the test drives.
private final class CoordinatedController: UIViewController {
    var coordinator: FakeTransitionCoordinator?

    override var transitionCoordinator: (any UIViewControllerTransitionCoordinator)? { coordinator }
}

private final class FakeTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    typealias Handler = (any UIViewControllerTransitionCoordinatorContext) -> Void

    let acceptsCompletion: Bool
    private var completions: [Handler] = []

    init(acceptsCompletion: Bool) {
        self.acceptsCompletion = acceptsCompletion
    }

    func endTransition() {
        let completions = completions
        self.completions = []
        completions.forEach { $0(self) }
    }

    func animate(alongsideTransition animation: Handler?, completion: Handler? = nil) -> Bool {
        guard acceptsCompletion else { return false }
        if let completion { completions.append(completion) }
        return true
    }

    func animateAlongsideTransition(in view: UIView?, animation: Handler?, completion: Handler? = nil) -> Bool {
        animate(alongsideTransition: animation, completion: completion)
    }

    func notifyWhenInteractionEnds(_ handler: @escaping Handler) {}
    func notifyWhenInteractionChanges(_ handler: @escaping Handler) {}

    var isAnimated: Bool { true }
    var presentationStyle: UIModalPresentationStyle { .overFullScreen }
    var initiallyInteractive: Bool { false }
    var isInterruptible: Bool { false }
    var isInteractive: Bool { false }
    var isCancelled: Bool { false }
    var transitionDuration: TimeInterval { 0.3 }
    var percentComplete: CGFloat { 0 }
    var completionVelocity: CGFloat { 1 }
    var completionCurve: UIView.AnimationCurve { .easeInOut }
    var containerView: UIView { UIView() }
    var targetTransform: CGAffineTransform { .identity }
    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { nil }
    func view(forKey key: UITransitionContextViewKey) -> UIView? { nil }
}

@MainActor
private final class MovingSource {
    var frame: CGRect?

    init(frame: CGRect?) {
        self.frame = frame
    }
}

@MainActor
private final class Log {
    var entries: [String] = []
}

@MainActor
private final class RequestModel: ObservableObject {
    @Published var request: ZoomableImageInfo?
}

/// A screen as the SDK's are: it keeps the request in a state it does not read itself, which its source sets and
/// reads, and which reaches the presenter through a modifier, as a binding.
private struct PresentingScreen: View {
    let source: SourceDriver
    let factory: PresentationFactory
    @State private var request: ZoomableImageInfo?

    var body: some View {
        DrivenSource(request: $request, driver: source)
            .modifier(PresentingModifier(request: $request, factory: factory))
    }
}

private struct PresentingModifier: ViewModifier {
    @Binding var request: ZoomableImageInfo?
    let factory: PresentationFactory

    func body(content: Content) -> some View {
        let factory = factory
        return content
            .fullscreenImageViewer($request, theme: OctopusTheme(), locale: nil, makePresentation: { factory.make() })
    }
}

/// Sets the request of a screen, as a tap on a photo does, and records the request the source last showed.
@MainActor
private final class SourceDriver {
    let tap = PassthroughSubject<ZoomableImageInfo?, Never>()
    /// `nil` before the source is shown.
    var shownRequest: ZoomableImageInfo??
}

private struct DrivenSource: View {
    @Binding var request: ZoomableImageInfo?
    let driver: SourceDriver

    var body: some View {
        driver.shownRequest = .some(request)
        return Color.clear
            .onReceive(driver.tap) { request = $0 }
    }
}

/// Makes the presentations of a screen, on a fake UIKit. A class: a closure given to the modifier would make it
/// change on every update of the screen, which would hide a missing dependency on the request.
@MainActor
private final class PresentationFactory {
    let uiKit: FakeUIKit

    init(uiKit: FakeUIKit) {
        self.uiKit = uiKit
    }

    func make() -> FullscreenViewerPresentation {
        let presentation = FullscreenViewerPresentation()
        uiKit.install(on: presentation)
        return presentation
    }
}

/// A UIKit view standing for a source, whose frame in the window UIKit knows.
@MainActor
private final class Probe {
    let geometry = FullscreenViewerSourceGeometry()
    weak var view: UIView?
}

private struct ProbeView: UIViewRepresentable {
    let probe: Probe

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        probe.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct SourceScreen: View {
    @ObservedObject var model: RequestModel
    let probe: Probe

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 100)
            ProbeView(probe: probe)
                .frame(width: 100, height: 50)
                .fullscreenViewerSource(probe.geometry, isInViewer: false)
            Spacer()
        }
        .fullscreenImageViewer($model.request, theme: OctopusTheme(), locale: nil)
    }
}

@MainActor
private func makeImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200), format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
    }
}
