//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore
import UIKit
import Octopus

extension View {
    /// Presents the fullscreen viewer over the screen whenever `request` is set, and sets it back to `nil` once the
    /// viewer is closed and its photo is back in its place.
    ///
    /// - Parameters:
    ///   - request: the photos to show. The source showing them stays hidden until it is back to `nil`.
    ///   - theme: the theme of the viewer's chrome.
    ///   - locale: the language the SDK overrides the device's with, if any.
    ///   - makePresentation: makes what presents the viewer. Replaced in tests.
    func fullscreenImageViewer(
        _ request: Binding<ZoomableImageInfo?>, theme: OctopusTheme, locale: Locale?,
        makePresentation: @escaping @MainActor () -> FullscreenViewerPresentation = { FullscreenViewerPresentation() }
    ) -> some View {
        // Read here, so that the presenter is updated whenever the request changes: a binding alone is not a
        // dependency.
        let currentRequest = request.wrappedValue
        return background(
            GeometryReader { proxy in
                FullscreenViewerPresenter(
                    request: currentRequest, requestBinding: request, theme: theme, locale: locale,
                    anchorGlobalFrame: { proxy.frame(in: .global) }, makePresentation: makePresentation)
            }
            .accessibilityHidden(true)
        )
    }
}

/// The anchor of the fullscreen viewer in a screen: an empty controller, covering the screen behind its content,
/// that presents the viewer from the controllers above it.
struct FullscreenViewerPresenter: UIViewControllerRepresentable {
    /// The request of the screen, as it was when this view was made: a change updates the presenter.
    let request: ZoomableImageInfo?
    /// The request of the screen, read when the update runs, and cleared once the viewer is gone.
    let requestBinding: Binding<ZoomableImageInfo?>
    let theme: OctopusTheme
    let locale: Locale?
    /// The frame of the anchor in the global coordinate space, in which the sources give their frame.
    let anchorGlobalFrame: @MainActor () -> CGRect?
    let makePresentation: @MainActor () -> FullscreenViewerPresentation

    func makeCoordinator() -> FullscreenViewerPresentation {
        makePresentation()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let anchor = UIViewController()
        anchor.view.backgroundColor = .clear
        anchor.view.isUserInteractionEnabled = false
        anchor.view.accessibilityElementsHidden = true
        return anchor
    }

    func updateUIViewController(_ anchor: UIViewController, context: Context) {
        let presentation = context.coordinator
        let requestBinding = requestBinding
        presentation.clearRequest = { requestBinding.wrappedValue = nil }
        presentation.anchorGlobalFrame = anchorGlobalFrame
        let theme = theme
        let locale = locale
        let textTone = context.environment.textTone
        // Out of the SwiftUI update: presenting lays the screen out again, and the request is cleared from the
        // completion of the dismissal.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                // The request as it is now, not as it was when this update was scheduled.
                presentation.update(
                    request: requestBinding.wrappedValue, anchor: anchor, theme: theme, locale: locale,
                    textTone: textTone)
            }
        }
    }

    static func dismantleUIViewController(_ anchor: UIViewController, coordinator: FullscreenViewerPresentation) {
        coordinator.anchorDidDisappear()
    }
}

/// Presents the fullscreen viewer for the requests of a screen, and hands the request back once the viewer is gone.
///
/// The order of the closing matters to the sources: the request's `onDismiss` is called before the photo flies back,
/// so that a carousel can move to the photo shown first, and the request is only cleared once the photo has landed,
/// when the source can be shown again.
@MainActor
final class FullscreenViewerPresentation {
    /// Sets the request of the screen back to `nil`.
    var clearRequest: () -> Void = {}
    /// The frame of the anchor in the global coordinate space. With the frame of the anchor in its window, it brings
    /// the frames the sources give to the window, which is what the transition works in.
    var anchorGlobalFrame: @MainActor () -> CGRect? = { nil }

    /// Asks UIKit to present the viewer, with its transition, from the given controller. Replaced in tests, whose host
    /// has no scene for a presentation to run in.
    var presentViewer: @MainActor (
        _ viewer: UIViewController,
        _ presenter: UIViewController,
        _ completion: @escaping @MainActor () -> Void) -> Void = { viewer, presenter, completion in
            presenter.present(viewer, animated: true, completion: completion)
        }
    /// Whether UIKit took the viewer in: it is presented, or being presented. Replaced in tests.
    var isViewerPresented: @MainActor (_ viewer: UIViewController) -> Bool = { viewer in
        viewer.presentingViewController != nil
    }
    /// Runs `action` once the transitions in progress on `presenter` are over, a navigation push for instance:
    /// UIKit may hold a presentation asked for during one until it ends. Replaced in tests.
    var afterPendingTransitions: @MainActor (
        _ presenter: UIViewController,
        _ action: @escaping @MainActor () -> Void) -> Void = { presenter, action in
            let runOnNextTurn = {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { action() }
                }
            }
            // UIKit does not keep a completion it refuses: the action then runs on its own, or the presentation
            // would wait for it forever, and the source would stay hidden.
            guard let coordinator = presenter.transitionCoordinator,
                  coordinator.animate(alongsideTransition: nil, completion: { _ in runOnNextTurn() }) else {
                runOnNextTurn()
                return
            }
        }
    /// Dismisses the viewer, animated or not. Replaced in tests.
    var dismissViewer: @MainActor (
        _ viewer: UIViewController,
        _ animated: Bool,
        _ completion: @escaping @MainActor () -> Void) -> Void = { viewer, animated, completion in
            viewer.dismiss(animated: animated, completion: completion)
        }

    /// The viewer, from its presentation until the end of its dismissal.
    private(set) var viewer: FullscreenImageViewerController?
    /// Kept alive here: a presented controller only holds its transitioning delegate weakly.
    private(set) var transition: FullscreenViewerTransition?
    private(set) var phase = Phase.idle
    private var request: ZoomableImageInfo?
    /// The index to close on, when the reader closes the viewer before it is fully presented.
    private var pendingCloseIndex: Int?
    /// Whether the anchor left the screen, which closes the viewer without giving anything back to the screen.
    private var isAnchorGone = false

    enum Phase {
        /// No viewer.
        case idle
        /// The photo flies to the viewer.
        case presenting
        /// The viewer is shown.
        case presented
        /// The photo flies back to its source.
        case dismissing
    }

    nonisolated init() {}

    /// Presents the viewer for a new request from the controllers above `anchor`, or dismisses it when the request
    /// is cleared while it is shown. A request that changes while the viewer is shown is ignored.
    func update(request: ZoomableImageInfo?, anchor: UIViewController, theme: OctopusTheme, locale: Locale?,
                textTone: TextTone = .formal) {
        if let request {
            guard phase == .idle else { return }
            present(request, from: anchor, theme: theme, locale: locale, textTone: textTone)
        } else if let viewer {
            close(at: viewer.currentIndex)
        }
    }

    /// The anchor left the screen: the viewer cannot be given back to it, so it goes away without its flight.
    ///
    /// While the viewer is still being presented, UIKit would ignore its dismissal: it goes away once it is shown
    /// (`didPresent`).
    func anchorDidDisappear() {
        guard let viewer, phase != .dismissing else { return }
        isAnchorGone = true
        guard phase == .presented else { return }
        takeAway(viewer)
    }

    /// Dismisses the viewer without its flight, and without giving anything back to the screen.
    private func takeAway(_ viewer: FullscreenImageViewerController) {
        phase = .dismissing
        dismissViewer(viewer, false) { [weak self] in
            self?.reset()
        }
    }

    /// The controller to present the viewer from: the topmost one presented in the anchor's window, which is the
    /// one showing the anchor's screen. Taken from the window rather than from the anchor's parents, which SwiftUI
    /// does not always link to the controllers above them. `nil` when the anchor is not on screen.
    static func presenter(for anchor: UIViewController) -> UIViewController? {
        guard var presenter = anchor.viewIfLoaded?.window?.rootViewController else { return nil }
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        return presenter
    }

    /// Brings a frame from the global coordinate space of SwiftUI to the window's.
    ///
    /// The two are the same for a screen that fills its window, but not in a sheet, whose hosting view is offset in
    /// the window: the offset is the one of the anchor, whose frame is known in both.
    static func windowFrame(of globalFrame: CGRect?, anchorGlobalFrame: CGRect?, anchorWindowFrame: CGRect) -> CGRect? {
        guard let globalFrame else { return nil }
        guard let anchorGlobalFrame else { return globalFrame }
        return globalFrame.offsetBy(dx: anchorWindowFrame.minX - anchorGlobalFrame.minX,
                                    dy: anchorWindowFrame.minY - anchorGlobalFrame.minY)
    }

    private func present(_ request: ZoomableImageInfo, from anchor: UIViewController, theme: OctopusTheme,
                         locale: Locale?, textTone: TextTone) {
        guard !request.items.isEmpty, let presenter = Self.presenter(for: anchor) else {
            // Nothing to show, or nowhere to show it: give the source back.
            clearRequest()
            return
        }
        let anchorView: UIView = anchor.view
        let sourceFrame = Self.windowFrame(
            of: request.sourceFrame, anchorGlobalFrame: anchorGlobalFrame(),
            anchorWindowFrame: anchorView.convert(anchorView.bounds, to: nil))
        let item = request.items[min(max(request.index, 0), request.items.count - 1)]
        let transition = FullscreenViewerTransition(
            sourceFrame: sourceFrame,
            sourceCornerRadius: request.sourceCornerRadius,
            sourceImage: item.transitionImage ?? item.image)
        if let liveSourceFrame = request.liveSourceFrame {
            // Where the source is when the viewer closes, after a rotation or a change of the layout above it.
            transition.dismissSourceFrame = { [weak self, weak anchor] in
                guard let self, let anchorView = anchor?.viewIfLoaded, anchorView.window != nil else { return nil }
                return Self.windowFrame(
                    of: liveSourceFrame(), anchorGlobalFrame: anchorGlobalFrame(),
                    anchorWindowFrame: anchorView.convert(anchorView.bounds, to: nil))
            }
        }
        let viewer = FullscreenImageViewerController(
            info: request, theme: theme, locale: locale, textTone: textTone,
            onClose: { [weak self] index in self?.close(at: index) })
        // The source is given back when the viewer fades rather than flies: the screen shows its photo again at once,
        // instead of an empty place that fills in when the fade ends.
        transition.dismissalWillFade = { [weak self] in
            guard let self, phase == .dismissing, !isAnchorGone else { return }
            clearRequest()
        }
        viewer.transitioningDelegate = transition

        self.request = request
        self.viewer = viewer
        self.transition = transition
        phase = .presenting
        // Strong: the screen may leave while the viewer is being presented, and SwiftUI then releases this
        // presentation. It must still be there once the viewer is shown, to take it away: nothing else can close it.
        presentViewer(viewer, presenter) {
            self.didPresent(viewer)
        }
        guard !isViewerPresented(viewer) else { return }
        // Not taken in yet: UIKit may be holding it until a transition ends. The viewer and its transition stay
        // alive until then, so that a viewer shown late can still be closed.
        afterPendingTransitions(presenter) { [weak self] in
            guard let self, self.viewer === viewer, phase == .presenting, !isViewerPresented(viewer) else { return }
            // Refused: give the source back, unless the screen is gone.
            let isAnchorGone = isAnchorGone
            reset()
            if !isAnchorGone {
                clearRequest()
            }
        }
    }

    private func didPresent(_ presented: FullscreenImageViewerController) {
        guard presented === viewer else {
            // Shown after it was taken for refused, its request already given back: nothing owns it any more, so it
            // goes away rather than stay on screen without a way to close it.
            dismissViewer(presented, false) {}
            return
        }
        guard phase == .presenting else { return }
        if isAnchorGone {
            // The screen left during the presentation.
            takeAway(presented)
            return
        }
        phase = .presented
        if let index = pendingCloseIndex {
            pendingCloseIndex = nil
            dismiss(at: index)
        }
    }

    private func close(at index: Int) {
        switch phase {
        case .presenting:
            // UIKit cannot dismiss a controller that is still being presented.
            pendingCloseIndex = index
        case .presented:
            dismiss(at: index)
        case .idle, .dismissing:
            break
        }
    }

    private func dismiss(at index: Int) {
        guard let viewer else { return }
        phase = .dismissing
        // Before the flight back: the source moves to the photo shown, and gives where the photo lands.
        request?.onDismiss?(index)
        dismissViewer(viewer, true) { [weak self] in
            self?.reset()
            self?.clearRequest()
        }
    }

    private func reset() {
        viewer = nil
        transition = nil
        request = nil
        pendingCloseIndex = nil
        isAnchorGone = false
        phase = .idle
    }
}
