//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

struct InsetableMainNavigationView: ViewModifier {
    /// Margin added to the bottom inset when the view touches the bottom edge of its window with no safe area there.
    static let screenEdgeMargin: CGFloat = 16

    let bottomSafeAreaInset: CGFloat
    let keepsMarginFromScreenEdge: Bool

    @State private var keyboardHeight = CGFloat.zero
    /// Bottom safe area of the container, before the inset of this modifier: the home indicator, a tab bar… `nil`
    /// while it has not been measured.
    @State private var containerBottomInset: CGFloat?
    /// Whether the container reaches the bottom of a window that has no bottom safe area, `nil` while it has not been
    /// measured.
    @State private var touchesScreenBottom: Bool?
    @State private var bottomInset: CGFloat

    init(bottomSafeAreaInset: CGFloat, keepsMarginFromScreenEdge: Bool) {
        self.bottomSafeAreaInset = bottomSafeAreaInset
        self.keepsMarginFromScreenEdge = keepsMarginFromScreenEdge
        self._bottomInset = .init(initialValue: bottomSafeAreaInset)
    }

    /// The bottom inset to apply: the one given by the integrator, plus ``screenEdgeMargin`` when the container
    /// touches the bottom edge of its window with no safe area between them. That is a view displayed down to the
    /// bottom of the screen on a device with a home button, or down to the bottom of a floating iPad window: what sits
    /// on it, like the "write a post" button, would touch the edge. A container that ends above something (a tab bar, a
    /// bar of the host app, the bottom of a sheet) gets nothing. Nothing is added either while the container is not
    /// measured, so that the content does not move on the other devices.
    static func bottomInset(bottomSafeAreaInset: CGFloat, containerBottomInset: CGFloat?,
                            touchesScreenBottom: Bool?) -> CGFloat {
        guard containerBottomInset == 0, touchesScreenBottom == true else { return bottomSafeAreaInset }
        return bottomSafeAreaInset + screenEdgeMargin
    }

    /// Whether a view whose frame, in its window's coordinates, is `frameInWindow` reaches the bottom edge of its
    /// window with no safe area there: the window has no bottom inset (a device with a home button, a floating iPad
    /// window) and the view goes down to the bottom of the window.
    static func touchesScreenBottom(frameInWindow: CGRect, windowBounds: CGRect, windowBottomInset: CGFloat) -> Bool {
        // Half a point of tolerance for the rounding of the frames to the pixel grid.
        windowBottomInset == 0 && frameInWindow.maxY >= windowBounds.maxY - 0.5
    }

    private var fullBottomInset: CGFloat {
        Self.bottomInset(bottomSafeAreaInset: bottomSafeAreaInset, containerBottomInset: containerBottomInset,
                         touchesScreenBottom: touchesScreenBottom)
    }

    func body(content: Content) -> some View {
        content
            .keyboardHeight($keyboardHeight)
            // SwiftUI puts a default spacing (8pt) between the content and even an empty inset: it is kept when the
            // integrator gives an inset, as it always was, and left out without one, so that the modifier changes
            // nothing when it adds no margin and adds exactly the margin otherwise.
            .safeAreaInsetCompat(edge: .bottom, spacing: bottomSafeAreaInset > 0 ? nil : 0) {
                Spacer().frame(height: bottomInset)
            }
            // Measured outside of the inset above, which would otherwise be part of what is measured.
            .modify {
                if keepsMarginFromScreenEdge {
                    $0
                        .readContainerBottomInset { containerMeasured(inset: $0, touches: nil) }
                        .readTouchesScreenBottom { containerMeasured(inset: nil, touches: $0) }
                } else {
                    $0
                }
            }
            .onValueChanged(of: keyboardHeight) { _ in
                updateBottomInset(fullBottomInset: fullBottomInset, animated: true)
            }
            .onValueChanged(of: bottomSafeAreaInset) { _ in
                updateBottomInset(fullBottomInset: fullBottomInset, animated: true)
            }
            .onAppear {
                updateBottomInset(fullBottomInset: fullBottomInset, animated: true)
            }
    }

    /// Takes a new measure of the container (`nil` for the one that did not change). The margin is not animated when
    /// it is first known, so that a screen does not slide up right after it appears.
    private func containerMeasured(inset: CGFloat??, touches: Bool??) {
        let wasMeasured = containerBottomInset != nil && self.touchesScreenBottom != nil
        let newBottomInset = inset ?? containerBottomInset
        let newTouchesScreenBottom = touches ?? self.touchesScreenBottom
        if newBottomInset != containerBottomInset { containerBottomInset = newBottomInset }
        if newTouchesScreenBottom != self.touchesScreenBottom { self.touchesScreenBottom = newTouchesScreenBottom }
        updateBottomInset(
            fullBottomInset: Self.bottomInset(bottomSafeAreaInset: bottomSafeAreaInset,
                                              containerBottomInset: newBottomInset,
                                              touchesScreenBottom: newTouchesScreenBottom),
            animated: wasMeasured)
    }

    private func updateBottomInset(fullBottomInset: CGFloat, animated: Bool) {
        let newBottomInset = keyboardHeight <= fullBottomInset ? fullBottomInset : 0
        guard newBottomInset != bottomInset else { return }
        var transaction = Transaction(animation: animated ? .default : nil)
        transaction.disablesAnimations = !animated
        withTransaction(transaction) {
            bottomInset = newBottomInset
        }
    }
}

private struct ContainerBottomInsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

/// Tells whether the view it is attached to reaches the bottom edge of its window with no safe area there (see
/// ``InsetableMainNavigationView/touchesScreenBottom(frameInWindow:windowBounds:windowBottomInset:)``).
///
/// It is measured in UIKit: the position of a view in its window is not something SwiftUI updates when UIKit moves
/// the view, as when it presents a sheet.
private struct ScreenBottomReader: UIViewRepresentable {
    let onChange: (Bool) -> Void

    func makeUIView(context: Context) -> ScreenBottomView {
        let view = ScreenBottomView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: ScreenBottomView, context: Context) {
        uiView.onChange = onChange
        uiView.reportSoon()
    }
}

/// View the size of the container that tells whether it touches the bottom of its window each time it can have
/// changed: when it moves to a window, is laid out, when its safe area changes and when its window is resized.
final class ScreenBottomView: UIView {
    var onChange: ((Bool) -> Void)?

    private var windowObservations: [NSKeyValueObservation] = []
    private var lastReported: Bool?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        windowObservations = []
        if let window {
            windowObservations.append(window.observe(\.bounds) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.report() }
            })
            windowObservations.append(window.observe(\.frame) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.report() }
            })
        }
        report()
        // A view presented by UIKit gets its final position after it moves to the window.
        reportSoon()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        report()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        report()
    }

    func reportSoon() {
        Task { @MainActor [weak self] in self?.report() }
    }

    /// Passes the measure on when it differs from the last one passed. It is passed on the next main-actor turn: this
    /// can be called while SwiftUI is updating its views, where writing a state is forbidden.
    ///
    /// The last measure is kept while the view is out of a window (a screen pushed over it, a full-screen cover), so
    /// that the margin does not go and come back on each navigation, and while one of its views is transformed: on
    /// iOS 15 to 18, a page sheet scales down the screen under it, and nothing lays the view out again once the sheet
    /// is dismissed, so a measure taken meanwhile would stay. A measure skipped for a transform is not taken again
    /// when the transform goes: the next layout, safe area change or SwiftUI update takes it.
    ///
    /// Nothing is measured either before the view is laid out (it has no size yet when it moves to its window) or
    /// while it is entirely below its window (where UIKit starts a sheet it presents): such a measure would be the
    /// first one, so the real one would then come as a change and the margin would be animated in.
    func report() {
        guard let window, !bounds.isEmpty, !Self.hasTransformedAncestor(self) else { return }
        let frameInWindow = convert(bounds, to: window)
        guard frameInWindow.minY < window.bounds.maxY else { return }
        let touchesScreenBottom = InsetableMainNavigationView.touchesScreenBottom(
            frameInWindow: frameInWindow,
            windowBounds: window.bounds,
            windowBottomInset: window.safeAreaInsets.bottom)
        guard touchesScreenBottom != lastReported else { return }
        lastReported = touchesScreenBottom
        Task { @MainActor [weak self] in self?.onChange?(touchesScreenBottom) }
    }

    /// Whether `view` or one of the views it is in has a transform, which moves it from where its layout put it.
    static func hasTransformedAncestor(_ view: UIView) -> Bool {
        var current: UIView? = view
        while let candidate = current {
            if !CATransform3DIsIdentity(candidate.layer.transform) { return true }
            current = candidate.superview
        }
        return false
    }
}

private extension View {
    /// Passes the bottom safe area inset of this view to `onChange`, the keyboard left out: the keyboard already
    /// removes the inset of ``InsetableMainNavigationView``.
    func readContainerBottomInset(_ onChange: @escaping (CGFloat?) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: ContainerBottomInsetPreferenceKey.self,
                                       value: proxy.safeAreaInsets.bottom)
            }
            .modify {
                if #available(iOS 14.0, *) {
                    $0.ignoresSafeArea(.keyboard)
                } else {
                    $0
                }
            }
        )
        .onPreferenceChange(ContainerBottomInsetPreferenceKey.self, perform: onChange)
    }

    /// Passes to `onChange` whether this view reaches the bottom edge of its window with no safe area there.
    func readTouchesScreenBottom(_ onChange: @escaping (Bool) -> Void) -> some View {
        background(
            ScreenBottomReader(onChange: onChange)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
    }
}

extension View {
    /// Apply a safe area inset to this view.
    /// When the keyboard is displayed, remove the inset
    /// - Parameters:
    ///   - bottomSafeAreaInset: the bottom safe area to set
    ///   - keepsMarginFromScreenEdge: add ``InsetableMainNavigationView/screenEdgeMargin`` to the inset when this
    ///     view touches the bottom edge of its window with no safe area there, as on a device with a home button.
    ///     When `true`, the modifier is applied even with a zero `bottomSafeAreaInset`, so that the margin can come
    ///     and go without changing the identity of this view, which would recreate it.
    @ViewBuilder
    func insetableMainNavigationView(
        bottomSafeAreaInset: CGFloat, keepsMarginFromScreenEdge: Bool = false) -> some View {
            if bottomSafeAreaInset > 0 || keepsMarginFromScreenEdge {
                self.modifier(
                    InsetableMainNavigationView(
                        bottomSafeAreaInset: bottomSafeAreaInset,
                        keepsMarginFromScreenEdge: keepsMarginFromScreenEdge
                    )
                )
            } else {
                self
            }
    }
}
