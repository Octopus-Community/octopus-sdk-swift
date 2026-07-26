//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Wraps the content's bounds anchor in an `Equatable` struct so the preference value stays
/// `Equatable` on iOS 13+ (a bare `Anchor<CGRect>?` only conforms to `Equatable` on iOS 15+).
/// Mirrors `BoundedPayload` from `VisibleItemsPreference`, the proven scroll-geometry mechanism.
private struct ScrollAnchorPayload: Equatable {
    var bounds: Anchor<CGRect>
}

/// Bounds anchor of the scroll content, resolved by the container's `GeometryReader`.
/// Using an anchor (rather than a `.background` + named coordinate space) is the mechanism
/// proven to re-evaluate on scroll in this codebase — see `View+PostsVisibilityScrollView`.
private struct ScrollContentAnchorKey: PreferenceKey {
    static var defaultValue: [ScrollAnchorPayload] { [] }
    static func reduce(value: inout [ScrollAnchorPayload], nextValue: () -> [ScrollAnchorPayload]) {
        value.append(contentsOf: nextValue())
    }
}

/// Applied to the *content* of a scroll view (e.g. the posts VStack): publishes the content's
/// bounds as an anchor so the container can read its live position/size while scrolling.
private struct ScrollDirectionAnchor: ViewModifier {
    func body(content: Content) -> some View {
        content.anchorPreference(key: ScrollContentAnchorKey.self, value: .bounds) {
            [ScrollAnchorPayload(bounds: $0)]
        }
    }
}

/// Applied to the scroll view (viewport): resolves the content anchor in its own
/// `GeometryReader` space and feeds the pure reducer to drive `isScrollingDown`. Mirrors
/// Android's `onScrollDownChanged` (50pt threshold + hysteresis + guards). Animates the flip.
@MainActor
private struct ScrollDirectionContainer: ViewModifier {
    /// Duration the detector ignores direction changes right after a flip, to absorb the
    /// layout shift caused by the bar/FAB animating (otherwise the geometry change feeds back
    /// and the state oscillates). Slightly longer than the 0.3s flip animation.
    private static let settleDelay: TimeInterval = 0.35

    let threshold: CGFloat
    @Binding var isScrollingDown: Bool
    @State private var state = ScrollDirectionState()
    @State private var isSettling = false

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .onPreferenceChange(ScrollContentAnchorKey.self) { @MainActor payloads in
                    guard let anchor = payloads.first?.bounds else { return }
                    let offset = proxy[anchor].minY

                    // While the flip animation settles, absorb the layout-induced offset shift
                    // (keep the baseline current, reset the accumulator) but do not re-evaluate.
                    guard !isSettling else {
                        state.lastOffset = offset
                        state.accumulator = 0
                        return
                    }

                    let newState = ScrollDirectionReducer.reduce(
                        state,
                        offset: offset,
                        contentHeight: proxy[anchor].height,
                        viewportHeight: proxy.size.height,
                        threshold: threshold)
                    state = newState
                    guard isScrollingDown != newState.isScrollingDown else { return }
                    // Plain write: consumers (bar + FAB) self-animate via `.animation(value:)`,
                    // which fires reliably even during a fast fling. A `withAnimation` here would
                    // not always propagate to the deep create-button view.
                    isScrollingDown = newState.isScrollingDown
                    isSettling = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(Self.settleDelay * 1_000_000_000))
                        state.accumulator = 0
                        isSettling = false
                    }
                }
        }
    }
}

extension View {
    /// Apply to the *content* of a scroll view (the scrollable VStack/LazyVStack).
    func scrollDirectionAnchor() -> some View {
        modifier(ScrollDirectionAnchor())
    }

    /// Apply to the scroll view itself. Drives `isScrollingDown` from scroll direction with a
    /// 50pt threshold, directional hysteresis, and pull-to-refresh / non-scrollable guards.
    func onScrollDirectionChange(threshold: CGFloat = ScrollDirectionReducer.defaultThreshold,
                                 isScrollingDown: Binding<Bool>) -> some View {
        modifier(ScrollDirectionContainer(threshold: threshold, isScrollingDown: isScrollingDown))
    }
}
