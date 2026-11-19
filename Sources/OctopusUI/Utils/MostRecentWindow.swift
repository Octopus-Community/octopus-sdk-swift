//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The most recent end of a thread, as the post and comment detail screens list it when they open on their newest
/// responses or once the member sent one: a window of the newest responses only, oldest at the top, that pages toward
/// older ones from its top. A thread of thousands of responses is then never loaded nor laid out whole.
enum MostRecentWindow {
    /// Number of responses listed when the window opens, and again once the member sent one.
    static let initialSize = 20
    /// Number of older responses each page loads when the member reaches the top of the window.
    static let olderPageSize = 50

    /// The window's responses in display order, oldest at the top, from the feed that lists them newest first.
    static func displayOrder<Item>(newestFirst items: [Item]) -> [Item] {
        Array(items.reversed())
    }

    /// The number of responses a refresh of the window asks for. It is never below what the member already paged
    /// in: a smaller one would drop the older responses above them and shift what they are reading.
    static func refreshSize(listedCount: Int) -> Int {
        max(initialSize, listedCount)
    }

    /// Whether a new version of the window brings the screen to its bottom: only when a newer response appeared while
    /// the previous newest one was on screen, so a member reading older responses is never pulled away from them.
    static func followsNewest(previousNewestId: String?, newestId: String?, previousNewestVisible: Bool) -> Bool {
        guard let previousNewestId, let newestId else { return false }
        return newestId != previousNewestId && previousNewestVisible
    }

    /// What the screen does as a new version of the window is listed.
    struct FollowStep: Equatable {
        /// The response to keep at the top of the screen, once older ones were inserted above it.
        let rowKeptInPlace: String?
        /// Whether to bring the screen to the bottom of the window.
        let scrollsToBottom: Bool
    }

    /// Keeps the screen on the most recent end as the window changes: on its bottom while it lands and whenever a newer
    /// response appears under the member's eyes, and on the same response when older ones are inserted above.
    /// - Parameters:
    ///   - ids: the window's responses, in display order.
    ///   - previousFirstId: the response at the top of the window when older ones were requested.
    ///   - landing: whether the screen is landing on the most recent end.
    ///   - pagesNewer: whether the window is the one around the response the screen opened on, paging newer responses
    ///     in from its bottom: those are not the newest of the thread, and following them would page the next ones in.
    ///     Still true once they all are: they stay lazy below the laid out part (see `laidOutEnd`), and a lazy stack of
    ///     rows of different heights, scrolled to its bottom while the keyboard moves, can loop in its layout.
    static func follow(ids: [String], previousNewestId: String?, previousNewestVisible: Bool,
                       previousFirstId: String?, landing: Bool, pagesNewer: Bool = false) -> FollowStep {
        FollowStep(
            rowKeptInPlace: rowKeptInPlace(previousFirstId: previousFirstId, ids: ids),
            scrollsToBottom: (landing && !ids.isEmpty) || !pagesNewer && followsNewest(
                previousNewestId: previousNewestId, newestId: ids.last, previousNewestVisible: previousNewestVisible))
    }

    /// The response the laid out part of the window starts from: the first one the window listed, all the ones below it
    /// laid out at once. Only the older pages inserted above it are lazy. A lazy stack of responses of different
    /// heights, scrolled to its bottom while the keyboard moves, can loop in its layout and freeze the screen; the
    /// screen scrolls to the bottom of the window, and only keeps in place an older response already on screen.
    ///
    /// While the window holds `initialSize` responses at most, the part holds all of them as they are first listed,
    /// unless a response already listed in the lazy part lies between them and the start: the first version of the
    /// window may be the few responses stored by a previous visit, and the server's window then inserts more above
    /// them as it lands. An older page stays lazy, even above a window left with fewer responses by hidden or deleted
    /// ones: the response kept in place as it is inserted must start the laid out part, where a scroll reaches it (see
    /// `ResponseKind.laidOutPartScrollAnchorId`). Only a page short enough for the page and the window to hold
    /// `initialSize` responses at most together still joins the part, as the responses alone cannot tell it from the
    /// server's window landing: the response kept in place then ends below that page's responses.
    ///
    /// A response already listed never moves between the two parts, which would recreate it: when the start is no
    /// longer listed, the part starts from the next response of it that still is, or from the top of a window listed
    /// anew.
    /// - Parameters:
    ///   - ids: the window's responses, in display order.
    ///   - previousIds: the responses of the previous version of the window, in display order.
    ///   - previousStart: the start of the laid out part in the previous version.
    static func laidOutStart(ids: [String], previousIds: [String], previousStart: String?) -> String? {
        let start: String?
        if let previousStart, ids.contains(previousStart) {
            start = previousStart
        } else if let previousStart {
            let listed = Set(ids)
            start = previousIds.drop { $0 != previousStart }.first(where: listed.contains) ?? ids.first
        } else {
            start = ids.first
        }
        guard let start, let index = ids.firstIndex(of: start) else { return ids.first }
        guard ids.count <= initialSize else { return start }
        // The part only extends upward through responses listed for the first time: one already listed in the lazy
        // part stays there, with every response above it, even once a deletion left fewer than `initialSize` below.
        let listedBefore = Set(previousIds)
        var extendedIndex = index
        while extendedIndex > 0 && !listedBefore.contains(ids[extendedIndex - 1]) { extendedIndex -= 1 }
        return ids[extendedIndex]
    }

    /// The response the laid out part of the window ends on, `nil` when it runs to the bottom of the window. The window
    /// around the response the screen opened on pages newer responses in from its bottom: the part ends on the newest
    /// response that window listed as it opened, and the newer pages stay lazy below it, as the older ones do above.
    /// Laid out at once, every page would make each frame of a scroll lay the whole thread out again. The part of the
    /// most recent end runs to its bottom, which the newer responses posted meanwhile join.
    ///
    /// A response already listed never moves between the parts: when the end is no longer listed, the part ends on the
    /// response above it that still is. A window listed anew ends its part on its newest response only while it pages
    /// newer ones in.
    /// - Parameters:
    ///   - ids: the window's responses, in display order.
    ///   - previousIds: the responses of the previous version of the window, in display order.
    ///   - previousEnd: the end of the laid out part in the previous version.
    ///   - pagesNewer: whether newer responses are still to load below the window.
    static func laidOutEnd(ids: [String], previousIds: [String], previousEnd: String?, pagesNewer: Bool) -> String? {
        let listed = Set(ids)
        if let previousEnd {
            if listed.contains(previousEnd) { return previousEnd }
            if let kept = previousIds.prefix(while: { $0 != previousEnd }).last(where: listed.contains) {
                return kept
            }
        } else if previousIds.contains(where: listed.contains) {
            // The part ran to the bottom of the previous version: the responses below it are already laid out.
            return nil
        }
        return pagesNewer ? ids.last : nil
    }

    /// The response to keep in place once older ones were inserted above it: the one that was at the top of the window
    /// when they were requested, as long as it is still listed below new ones. `nil` when nothing was inserted above.
    static func rowKeptInPlace(previousFirstId: String?, ids: [String]) -> String? {
        guard let previousFirstId, let first = ids.first, first != previousFirstId,
              ids.contains(previousFirstId) else { return nil }
        return previousFirstId
    }
}

/// Where the laid out part of the window starts and ends, remembered across the versions of the window a list view
/// renders. Read while the view's body is computed, so the first version is split before it is rendered: a response
/// listed in the wrong part for one frame would move to the other one, and be recreated, on the next.
final class MostRecentWindowLaidOutStart {
    private var start: String?
    private var end: String?
    private var ids: [String] = []
    private var windowId: String?

    /// The indices in `ids` of the laid out part (see `MostRecentWindow.laidOutStart` and
    /// `MostRecentWindow.laidOutEnd`).
    /// - Parameters:
    ///   - pagesNewer: whether newer responses are still to load below the window.
    ///   - windowId: the window `ids` come from. Another window starts its own laid out part, whatever responses the
    ///     two share: the most recent end listed once the member sent a response from the window around the one the
    ///     screen opened on is laid out down to its bottom, which the screen scrolls to with the keyboard up. Below a
    ///     part ending where the previous window's did, the sent response would be lazy, and a lazy stack of rows of
    ///     different heights, scrolled to its bottom while the keyboard moves, can loop in its layout.
    func part(in ids: [String], pagesNewer: Bool, windowId: String? = nil) -> Range<Int> {
        if windowId != self.windowId {
            reset()
            self.windowId = windowId
        }
        if ids != self.ids {
            start = MostRecentWindow.laidOutStart(ids: ids, previousIds: self.ids, previousStart: start)
            end = MostRecentWindow.laidOutEnd(ids: ids, previousIds: self.ids, previousEnd: end,
                                              pagesNewer: pagesNewer)
            self.ids = ids
        }
        let lowerBound = start.flatMap { ids.firstIndex(of: $0) } ?? 0
        let upperBound = end.flatMap { ids.firstIndex(of: $0) }.map { $0 + 1 } ?? ids.count
        return lowerBound..<max(lowerBound, upperBound)
    }

    /// Forgets the window, so the next one listed starts its own laid out part.
    func reset() {
        start = nil
        end = nil
        ids = []
        windowId = nil
    }
}
