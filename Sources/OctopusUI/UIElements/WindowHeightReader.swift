//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// Reports the height of the window that hosts the view it is attached to.
///
/// `UIScreen.main` is the main screen's size, not the size of the window the SDK is shown in: it is wrong on a
/// second screen or in an iPad window shorter than the screen (Stage Manager, windowed apps), and it is deprecated
/// since iOS 16. The height is `0` while the view is not in a window yet; it follows the window when it is rotated or
/// resized.
private struct WindowHeightReader: UIViewRepresentable {
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> WindowHeightView {
        let view = WindowHeightView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.onChange = publish
        return view
    }

    func updateUIView(_ uiView: WindowHeightView, context: Context) {
        uiView.onChange = publish
    }

    private func publish(_ newHeight: CGFloat) {
        // Writing an unchanged value would still invalidate the views that read the binding.
        if height != newHeight {
            height = newHeight
        }
    }
}

/// Zero-size view that tells the height of its window each time it can have changed.
private final class WindowHeightView: UIView {
    var onChange: ((CGFloat) -> Void)?

    private var windowObservations: [NSKeyValueObservation] = []
    private var lastReportedHeight: CGFloat?

    /// Observes what changes when the window is resized. UIKit resizes a window through its `frame` setter, not its
    /// `bounds` one: on a rotation, from iOS 16 to 26 at least, `frame` is the change that fires, with the new bounds
    /// already set, and `bounds` never does. `bounds` stays observed for a window whose bounds are set directly. From
    /// iOS 16, the scene's geometry, which UIKit documents as observable, covers a resize that would not go through
    /// `frame`; its duplicate of the `frame` change is dropped by ``reportWindowHeight()``. It is the scene the window
    /// has when the view moves to it: a window moved to another scene later keeps the `frame` signal only.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        windowObservations = []
        if let window {
            windowObservations.append(window.observe(\.bounds) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.reportWindowHeight() }
            })
            windowObservations.append(window.observe(\.frame) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.reportWindowHeight() }
            })
            if #available(iOS 16.0, *), let windowScene = window.windowScene {
                windowObservations.append(windowScene.observe(\.effectiveGeometry) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.reportWindowHeight() }
                })
            }
        }
        reportWindowHeight()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportWindowHeight()
    }

    /// Passes the window's height on when it differs from the last one passed. The binding is written on the next
    /// main-actor turn: this can be called while SwiftUI is updating its views, where writing a state is forbidden.
    private func reportWindowHeight() {
        let height = window?.bounds.height ?? 0
        guard height != lastReportedHeight else { return }
        lastReportedHeight = height
        Task { @MainActor [weak self] in self?.onChange?(height) }
    }
}

extension View {
    /// Writes the height of the window hosting this view into `height` (`0` while it is unknown), and keeps it up
    /// to date when the window is rotated or resized.
    func readWindowHeight(_ height: Binding<CGFloat>) -> some View {
        background(
            WindowHeightReader(height: height)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
    }
}

/// The window height to size against: the measured one, or the screen's while the window is not known yet.
///
/// The window height reaches the views one main-actor turn after the first layout pass, and a view that applied no
/// cap during that pass would size itself uncapped (an oversized sheet detent, a notice at its full height) before
/// the window is known. The screen's height is the best guess available then, and only then: it is the main screen's
/// size, wrong in a resized iPad window or on a second screen, so it is never used once the window has reported.
func resolvedWindowHeight(measured: CGFloat, fallback: CGFloat) -> CGFloat {
    measured > 0 ? measured : fallback
}

/// Height of the main screen, the provisional window height while the real one is unknown (see
/// ``resolvedWindowHeight(measured:fallback:)``).
@MainActor
var provisionalWindowHeight: CGFloat { UIScreen.main.bounds.height }
