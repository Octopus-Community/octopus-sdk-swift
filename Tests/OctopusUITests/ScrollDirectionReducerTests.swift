//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import CoreGraphics
@testable import OctopusUI

@Suite
struct ScrollDirectionReducerTests {
    private let tall: CGFloat = 2000
    private let viewport: CGFloat = 800

    @Test func scrollingDownPastThresholdHides() {
        var state = ScrollDirectionState()
        state = ScrollDirectionReducer.reduce(state, offset: -60, contentHeight: tall, viewportHeight: viewport)
        #expect(state.isScrollingDown == true)
    }

    @Test func subThresholdDoesNotToggle() {
        var state = ScrollDirectionState()
        state = ScrollDirectionReducer.reduce(state, offset: -30, contentHeight: tall, viewportHeight: viewport)
        #expect(state.isScrollingDown == false)
    }

    @Test func directionReversalResetsAccumulator() {
        var state = ScrollDirectionState()
        state = ScrollDirectionReducer.reduce(state, offset: -30, contentHeight: tall, viewportHeight: viewport)
        state = ScrollDirectionReducer.reduce(state, offset: -10, contentHeight: tall, viewportHeight: viewport)
        #expect(state.isScrollingDown == false)
        #expect(state.accumulator == 20) // accumulator is +20 because the second move is upward (after the reversal reset)
    }

    @Test func scrollingUpPastThresholdShows() {
        var state = ScrollDirectionState(isScrollingDown: true, accumulator: 0, lastOffset: -200)
        state = ScrollDirectionReducer.reduce(state, offset: -140, contentHeight: tall, viewportHeight: viewport)
        #expect(state.isScrollingDown == false)
    }

    @Test func overscrollAtTopAlwaysShows() {
        var state = ScrollDirectionState(isScrollingDown: true, accumulator: -40, lastOffset: -10)
        state = ScrollDirectionReducer.reduce(state, offset: 40, contentHeight: tall, viewportHeight: viewport)
        #expect(state.isScrollingDown == false)
        #expect(state.accumulator == 0)
    }

    @Test func nonScrollableContentNeverHides() {
        var state = ScrollDirectionState()
        state = ScrollDirectionReducer.reduce(state, offset: -500, contentHeight: 500, viewportHeight: 800)
        #expect(state.isScrollingDown == false)
    }

    @Test func exactDownThresholdFlipsState() {
        var state = ScrollDirectionState()
        state = ScrollDirectionReducer.reduce(state, offset: -50, contentHeight: tall, viewportHeight: viewport)
        #expect(state.isScrollingDown == true)
    }

    @Test func exactUpThresholdFlipsState() {
        var state = ScrollDirectionState(isScrollingDown: true, accumulator: 0, lastOffset: -200)
        state = ScrollDirectionReducer.reduce(state, offset: -150, contentHeight: tall, viewportHeight: viewport)
        #expect(state.isScrollingDown == false)
    }
}
