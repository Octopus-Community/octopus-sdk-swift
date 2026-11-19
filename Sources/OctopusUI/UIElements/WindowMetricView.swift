//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// Zero-size view that tells a metric of its window (its height, its safe area…) each time it can have changed.
final class WindowMetricView<Metric: Equatable & Sendable>: UIView {
    var onChange: ((Metric) -> Void)?

    /// Reads the metric from the window, `nil` while the view is not in one.
    private let measure: (UIWindow?) -> Metric
    private var windowObservations: [NSKeyValueObservation] = []
    private var lastReportedMetric: Metric?

    init(measure: @escaping (UIWindow?) -> Metric) {
        self.measure = measure
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Observes what changes when the window is resized. UIKit resizes a window through its `frame` setter, not its
    /// `bounds` one: on a rotation, from iOS 16 to 26 at least, `frame` is the change that fires, with the new bounds
    /// already set, and `bounds` never does. `bounds` stays observed for a window whose bounds are set directly. From
    /// iOS 16, the scene's geometry, which UIKit documents as observable, covers a resize that would not go through
    /// `frame`; its duplicate of the `frame` change is dropped by ``reportMetric()``. It is the scene the window has
    /// when the view moves to it: a window moved to another scene later keeps the `frame` signal only. A change is read
    /// one main-actor turn after it is observed, when UIKit has also updated what follows from the new size, like the
    /// window's safe area insets.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        windowObservations = []
        if let window {
            windowObservations.append(window.observe(\.bounds) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.reportMetric() }
            })
            windowObservations.append(window.observe(\.frame) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.reportMetric() }
            })
            if #available(iOS 16.0, *), let windowScene = window.windowScene {
                windowObservations.append(windowScene.observe(\.effectiveGeometry) { [weak self] _, _ in
                    Task { @MainActor [weak self] in self?.reportMetric() }
                })
            }
        }
        reportMetric()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportMetric()
    }

    /// Passes the window's metric on when it differs from the last one passed. The binding is written on the next
    /// main-actor turn: this can be called while SwiftUI is updating its views, where writing a state is forbidden.
    private func reportMetric() {
        let metric = measure(window)
        guard metric != lastReportedMetric else { return }
        lastReportedMetric = metric
        Task { @MainActor [weak self] in self?.onChange?(metric) }
    }
}
