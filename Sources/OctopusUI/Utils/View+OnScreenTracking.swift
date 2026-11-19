//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The views of a scroll view's content whose presence on screen it can report, one at a time per role.
enum TrackedViewRole: Equatable {
    /// The loader of older items, at the top of a list that opens on its most recent end.
    case olderItemsLoader
    /// The loader of newer items, below the window of a list opened on one of its items.
    case newerItemsLoader
    /// The newest item of a list that opens on its most recent end, at the bottom of its window.
    case newestItem
}

/// The coordinate space of the scroll view decorated with `onTrackedViewOnScreenChanged(of:settleDelay:perform:)`.
private let trackedViewCoordinateSpace = "OctopusSDK.trackedViewCoordinateSpace"

private struct TrackedViewPayload: Equatable {
    var role: TrackedViewRole
    /// The frame of the tracked view in the scroll view's coordinate space. A frame, not an anchor: it changes on
    /// every frame of a scroll, programmatic ones included, so the container sees the view move and come to rest.
    var frame: CGRect
}

private struct TrackedViewFrameKey: PreferenceKey {
    static var defaultValue: [TrackedViewPayload] { [] }
    static func reduce(value: inout [TrackedViewPayload], nextValue: () -> [TrackedViewPayload]) {
        value.append(contentsOf: nextValue())
    }
}

/// Applied to the scroll view (viewport): tells whether the view marked with `tracksOnScreenPresence(as:)` in its
/// content, with the same role, rests on screen or has left it.
@MainActor
private struct TrackedViewOnScreenContainer: ViewModifier {
    let role: TrackedViewRole
    let settleDelay: TimeInterval
    let action: (Bool) -> Void
    /// A reference: updated on every frame of a scroll, it must not invalidate the body.
    @State private var settling = TrackedViewSettling()

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .coordinateSpace(name: trackedViewCoordinateSpace)
                .onPreferenceChange(TrackedViewFrameKey.self) { @MainActor payloads in
                    settling.update(frame: payloads.first { $0.role == role }?.frame,
                                    viewport: CGRect(origin: .zero, size: proxy.size),
                                    delay: settleDelay, action: action)
                }
        }
    }
}

/// Reports a tracked view on screen once it rested there for a delay, and off screen once it stayed off for that
/// delay. A view crossing the screen during a scroll is not reported, nor one that shows or leaves for a single frame:
/// a programmatic scroll made while the scroll view bounces at its top can show the view for one frame, or move it
/// away for one frame before the bounce brings it back.
@MainActor
private final class TrackedViewSettling {
    private var frame: CGRect?
    /// What was last reported.
    private var isOnScreen = false
    private var pendingReport: (onScreen: Bool, task: Task<Void, Never>)?

    func update(frame: CGRect?, viewport: CGRect, delay: TimeInterval, action: @escaping (Bool) -> Void) {
        guard frame != self.frame else { return }
        self.frame = frame
        if frame.map(viewport.intersects) ?? false {
            // Every move postpones the report, made again each time the view comes to rest on screen.
            report(onScreen: true, after: delay, action: action)
        } else if pendingReport?.onScreen == true {
            // The view crossed the screen without resting on it.
            pendingReport?.task.cancel()
            pendingReport = nil
            if isOnScreen { report(onScreen: false, after: delay, action: action) }
        } else if isOnScreen && pendingReport == nil {
            // Moving or not, the view is reported off screen once it stayed off for the delay.
            report(onScreen: false, after: delay, action: action)
        }
    }

    private func report(onScreen: Bool, after delay: TimeInterval, action: @escaping (Bool) -> Void) {
        pendingReport?.task.cancel()
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            pendingReport = nil
            isOnScreen = onScreen
            action(onScreen)
        }
        pendingReport = (onScreen, task)
    }
}

extension View {
    /// Marks this view, inside the content of a scroll view decorated with
    /// `onTrackedViewOnScreenChanged(of:settleDelay:perform:)` for the same role, as the one whose presence on screen
    /// the scroll view reports.
    ///
    /// Unlike `onAppear` / `onDisappear`, it holds in a non-lazy stack, which makes every row appear at once and none
    /// disappear when it scrolls off screen.
    func tracksOnScreenPresence(as role: TrackedViewRole = .olderItemsLoader) -> some View {
        tracksOnScreenPresence(as: role, when: true)
    }

    /// Same as `tracksOnScreenPresence(as:)`, only while `isTracked`: for a role a row of a list takes in turn, such
    /// as its newest one, without changing the type of the row, which would recreate it.
    func tracksOnScreenPresence(as role: TrackedViewRole, when isTracked: Bool) -> some View {
        // Only while tracked: the role of the newest response is on every row of a list.
        background(Group {
            if isTracked {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TrackedViewFrameKey.self,
                        value: [TrackedViewPayload(role: role,
                                                   frame: proxy.frame(in: .named(trackedViewCoordinateSpace)))])
                }
            }
        })
    }

    /// Decorator of a scroll view: calls `action` with whether the view marked with `tracksOnScreenPresence(as:)` for
    /// `role` in its content is on screen. `true` once it rested on screen for `settleDelay`, and again each time it
    /// comes to rest after moving on it; `false` once it stayed off screen for `settleDelay`. A tracked view removed
    /// from the content counts as off screen.
    func onTrackedViewOnScreenChanged(of role: TrackedViewRole = .olderItemsLoader,
                                      settleDelay: TimeInterval = 0.1,
                                      perform action: @escaping (Bool) -> Void) -> some View {
        modifier(TrackedViewOnScreenContainer(role: role, settleDelay: settleDelay, action: action))
    }
}
