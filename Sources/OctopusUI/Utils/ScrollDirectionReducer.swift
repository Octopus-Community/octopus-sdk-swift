//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import CoreGraphics

/// Pure, SwiftUI-free state for scroll-direction detection.
struct ScrollDirectionState: Equatable {
    var isScrollingDown = false
    var accumulator: CGFloat = 0
    var lastOffset: CGFloat = 0
}

/// Pure reducer mirroring Android's `onScrollDownChanged` (octopus-sdk-android):
/// accumulate the scroll delta until a threshold is crossed, with directional
/// hysteresis and two iOS-only guards (pull-to-refresh, non-scrollable content).
enum ScrollDirectionReducer {
    /// Sustained scroll delta (pt) before the state flips. Matches Android's
    /// `onScrollDownChanged(threshold = 50f)` for cross-platform parity.
    static let defaultThreshold: CGFloat = 50

    /// - Parameters:
    ///   - offset: vertical position of the content top in the scroll viewport's coordinate
    ///             space. `0` at rest top, negative while scrolled down into the content,
    ///             positive when overscrolling at the top (e.g. pull-to-refresh).
    ///   - contentHeight: height of the scrollable content.
    ///   - viewportHeight: height of the visible scroll area.
    ///   - threshold: sustained delta (pt) required to flip the state.
    static func reduce(_ state: ScrollDirectionState,
                       offset: CGFloat,
                       contentHeight: CGFloat,
                       viewportHeight: CGFloat,
                       threshold: CGFloat = defaultThreshold) -> ScrollDirectionState {
        var newState = state
        let delta = offset - state.lastOffset
        newState.lastOffset = offset

        // Guard 1 — content not scrollable: always expanded/visible.
        if contentHeight <= viewportHeight {
            newState.isScrollingDown = false
            newState.accumulator = 0
            return newState
        }

        // Guard 2 — at top / overscroll (pull-to-refresh): always expanded/visible.
        if offset >= 0 {
            newState.isScrollingDown = false
            newState.accumulator = 0
            return newState
        }

        // Hysteresis — reset the accumulator on direction reversal.
        if (delta < 0 && newState.accumulator > 0) || (delta > 0 && newState.accumulator < 0) {
            newState.accumulator = 0
        }
        newState.accumulator += delta

        if newState.accumulator <= -threshold {
            newState.isScrollingDown = true
            newState.accumulator = 0
        } else if newState.accumulator >= threshold {
            newState.isScrollingDown = false
            newState.accumulator = 0
        }
        return newState
    }
}
