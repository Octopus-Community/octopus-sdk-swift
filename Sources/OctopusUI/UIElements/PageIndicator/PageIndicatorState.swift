//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// What the page indicator of a carousel shows: at most five dots, a sliding window over the pages.
///
/// The indicator never shows more than `maxDots` dots. When there are more pages, the dots at the edge of the
/// window that hide further pages are drawn smaller, and the selected dot stays at a position that tells the user
/// whether there is more to see in the direction they are moving.
struct PageIndicatorState: Equatable {
    enum Dot: Equatable {
        case normal
        case small
    }

    /// The dots, from left to right.
    let dots: [Dot]
    /// Position, in `dots`, of the dot of the current page.
    let selectedPosition: Int
    /// The number of pages of the carousel.
    let pageCount: Int
    /// The page of the first dot. It moves by one page when the window slides, which is what lets the view slide the
    /// dots: a dot is the dot of a page, not of a position in the row.
    let firstPage: Int

    private init(pageCount: Int, currentIndex: Int, dots: [Dot], selectedPosition: Int) {
        self.dots = dots
        self.selectedPosition = selectedPosition
        self.pageCount = pageCount
        self.firstPage = currentIndex - selectedPosition
    }

    /// The dot of `page`, or nil when the page is outside the window.
    func dot(forPage page: Int) -> Dot? {
        let position = page - firstPage
        return dots.indices.contains(position) ? dots[position] : nil
    }

    /// Number of dots displayed at most.
    private static let maxDots = 5
    /// From this page count on, the carousel also displays a "current / total" counter: as soon as there is more
    /// than one photo, the counter tells how many there are.
    private static let minPagesWithCounter = 2

    /// Builds the state of the indicator.
    /// - Parameters:
    ///   - pageCount: the number of pages of the carousel.
    ///   - currentIndex: the 0-based index of the current page.
    ///   - lastMoveForward: whether the last move went toward the end (true) or toward the start (false).
    /// - Returns: the state, or nil when there is no need for an indicator (fewer than two pages).
    static func make(pageCount: Int, currentIndex: Int, lastMoveForward: Bool) -> PageIndicatorState? {
        guard pageCount >= 2 else { return nil }

        if pageCount <= maxDots {
            return PageIndicatorState(
                pageCount: pageCount, currentIndex: currentIndex,
                dots: Array(repeating: .normal, count: pageCount), selectedPosition: currentIndex)
        }

        if currentIndex == pageCount - 1 {
            return PageIndicatorState(
                pageCount: pageCount, currentIndex: currentIndex,
                dots: [.small, .normal, .normal, .normal, .normal], selectedPosition: 4)
        }

        let nearStart = lastMoveForward ? currentIndex <= 3 : currentIndex <= 2
        // Going back from the last photo, the dot leaves the fifth position one step at a time, down to the third,
        // while the last photo is still in the window: the last dot keeps its normal size.
        let pagesAfter = pageCount - 1 - currentIndex
        if !lastMoveForward && !nearStart && pagesAfter <= 2 {
            return PageIndicatorState(
                pageCount: pageCount, currentIndex: currentIndex,
                dots: [.small, .normal, .normal, .normal, .normal], selectedPosition: 4 - pagesAfter)
        }
        if nearStart {
            return PageIndicatorState(
                pageCount: pageCount, currentIndex: currentIndex,
                dots: [.normal, .normal, .normal, .normal, .small], selectedPosition: currentIndex)
        }

        return PageIndicatorState(
            pageCount: pageCount, currentIndex: currentIndex,
            dots: [.small, .normal, .normal, .normal, .small],
            selectedPosition: lastMoveForward ? 3 : 2)
    }

    /// Whether the carousel displays a "current / total" counter next to the dots.
    static func showsCounter(pageCount: Int) -> Bool {
        pageCount >= minPagesWithCounter
    }
}
