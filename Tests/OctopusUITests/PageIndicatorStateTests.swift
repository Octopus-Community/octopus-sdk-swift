//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

@Suite
struct PageIndicatorStateTests {
    private typealias Dot = PageIndicatorState.Dot

    @Test func singlePageHasNoIndicator() {
        #expect(PageIndicatorState.make(pageCount: 1, currentIndex: 0, lastMoveForward: true) == nil)
        #expect(PageIndicatorState.make(pageCount: 0, currentIndex: 0, lastMoveForward: true) == nil)
    }

    @Test func threePagesOneDotEach() throws {
        let state = try #require(PageIndicatorState.make(pageCount: 3, currentIndex: 1, lastMoveForward: true))
        #expect(state.dots == [.normal, .normal, .normal])
        #expect(state.selectedPosition == 1)
    }

    @Test func fivePagesOneDotEachWhateverTheDirection() throws {
        for forward in [true, false] {
            let state = try #require(
                PageIndicatorState.make(pageCount: 5, currentIndex: 4, lastMoveForward: forward))
            #expect(state.dots == Array(repeating: Dot.normal, count: 5))
            #expect(state.selectedPosition == 4)
        }
    }

    @Test func sixthOfEightSelectsTheFourthDot() throws {
        let state = try #require(PageIndicatorState.make(pageCount: 8, currentIndex: 5, lastMoveForward: true))
        #expect(state.dots == [.small, .normal, .normal, .normal, .small])
        #expect(state.selectedPosition == 3)
    }

    @Test(arguments: 0...3)
    func firstFourAdvanceFromFirstToFourthPosition(index: Int) throws {
        let state = try #require(PageIndicatorState.make(pageCount: 8, currentIndex: index, lastMoveForward: true))
        #expect(state.dots == [.normal, .normal, .normal, .normal, .small])
        #expect(state.selectedPosition == index)
    }

    @Test func lastPageSelectsFifth() throws {
        let state = try #require(PageIndicatorState.make(pageCount: 8, currentIndex: 7, lastMoveForward: true))
        #expect(state.dots == [.small, .normal, .normal, .normal, .normal])
        #expect(state.selectedPosition == 4)
    }

    @Test func goingBackSelectsThird() throws {
        let state = try #require(PageIndicatorState.make(pageCount: 8, currentIndex: 4, lastMoveForward: false))
        #expect(state.dots == [.small, .normal, .normal, .normal, .small])
        #expect(state.selectedPosition == 2)
    }

    @Test func goingBackFromTheLastMovesOneDotAtATime() throws {
        // From the last photo (fifth dot), the dot moves to the fourth, then the third, where it stays.
        let secondToLast = try #require(PageIndicatorState.make(pageCount: 10, currentIndex: 8, lastMoveForward: false))
        #expect(secondToLast.dots == [.small, .normal, .normal, .normal, .normal])
        #expect(secondToLast.selectedPosition == 3)

        let thirdToLast = try #require(PageIndicatorState.make(pageCount: 10, currentIndex: 7, lastMoveForward: false))
        #expect(thirdToLast.dots == [.small, .normal, .normal, .normal, .normal])
        #expect(thirdToLast.selectedPosition == 2)

        let further = try #require(PageIndicatorState.make(pageCount: 10, currentIndex: 6, lastMoveForward: false))
        #expect(further.dots == [.small, .normal, .normal, .normal, .small])
        #expect(further.selectedPosition == 2)
    }

    @Test func goingBackNearStartFollowsIndex() throws {
        let state = try #require(PageIndicatorState.make(pageCount: 8, currentIndex: 1, lastMoveForward: false))
        #expect(state.dots == [.normal, .normal, .normal, .normal, .small])
        #expect(state.selectedPosition == 1)
    }

    @Test func firstPageIsTheFirstPageUpToFivePages() throws {
        for index in 0..<5 {
            let state = try #require(PageIndicatorState.make(pageCount: 5, currentIndex: index, lastMoveForward: true))
            #expect(state.firstPage == 0)
        }
    }

    @Test func walkingForwardSlidesTheWindowOneStepAtATime() throws {
        let firstPages = try (0..<10).map {
            try #require(PageIndicatorState.make(pageCount: 10, currentIndex: $0, lastMoveForward: true)).firstPage
        }
        #expect(firstPages == [0, 0, 0, 0, 1, 2, 3, 4, 5, 5])
    }

    @Test func walkingBackSlidesTheWindowOneStepAtATime() throws {
        let firstPages = try (0..<10).reversed().map {
            try #require(PageIndicatorState.make(pageCount: 10, currentIndex: $0, lastMoveForward: false)).firstPage
        }
        #expect(firstPages == [5, 5, 5, 4, 3, 2, 1, 0, 0, 0])
    }

    @Test func turningBackInTheMiddleKeepsTheWindow() throws {
        let forward = try #require(PageIndicatorState.make(pageCount: 10, currentIndex: 5, lastMoveForward: true))
        let back = try #require(PageIndicatorState.make(pageCount: 10, currentIndex: 4, lastMoveForward: false))
        #expect(forward.firstPage == back.firstPage)
    }

    @Test func dotOfAPageOutsideTheWindowIsNil() throws {
        let state = try #require(PageIndicatorState.make(pageCount: 10, currentIndex: 5, lastMoveForward: true))
        #expect(state.pageCount == 10)
        #expect(state.dot(forPage: 1) == nil)
        #expect(state.dot(forPage: 2) == .small)
        #expect(state.dot(forPage: 5) == .normal)
        #expect(state.dot(forPage: 6) == .small)
        #expect(state.dot(forPage: 7) == nil)
    }

    @Test(arguments: [0, 1])
    func noCounterWithoutSeveralPages(pageCount: Int) {
        #expect(!PageIndicatorState.showsCounter(pageCount: pageCount))
    }

    @Test(arguments: [2, 5, 6, 10])
    func counterFromTwoPages(pageCount: Int) {
        #expect(PageIndicatorState.showsCounter(pageCount: pageCount))
    }

    @Test func dotsUnchangedByTheCounter() throws {
        let two = try #require(PageIndicatorState.make(pageCount: 2, currentIndex: 0, lastMoveForward: true))
        #expect(two.dots == [.normal, .normal])
        #expect(PageIndicatorState.make(pageCount: 1, currentIndex: 0, lastMoveForward: true) == nil)
    }
}
