//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Paces the pages of older responses that the most recent end of a thread loads from its top, one at a time.
///
/// A page inserts its responses above the one at the top of the window, which a scroll then keeps in place: the loader
/// leaves the screen, and the member stays on what they read. That scroll is lost when the scroll view still moves as
/// it is made, under the member's finger or bouncing at its top after a fling, and the loader stays on screen. Asking
/// for the next page then would load page after page, each one moving the member further from what they read: the
/// scroll is made again each time the loader rests on screen, until it leaves it.
///
/// The screen reports what happens and performs the returned `Action`. It also calls `timedOut(generation:canLoad:)`
/// a while after a page is loaded and after each scroll keeping a response in place, with the `generation` read when
/// the page was asked for and when the scroll was made: a page whose responses were all listed already lists nothing
/// above the window, a member can hold the scroll view past its top longer than a bounce lasts, and the scroll made
/// again for a page too short to push the loader away leaves it where it was, unreported.
struct OlderPagesPacing: Equatable {
    enum Phase: Equatable {
        /// No page is loading: the next one loads once the loader rests on screen.
        case idle
        /// A page is loading. `keptId` is the response at the top of the window when it was asked for.
        case loading(keptId: String?)
        /// The page is listed above `keptId`, which a scroll keeps in place. `timedOut` once the loader stayed on
        /// screen without coming to rest until the timeout, and the scroll was made again.
        case keepingInPlace(keptId: String, timedOut: Bool)
    }

    /// What the screen does after an event.
    enum Action: Equatable {
        case none
        /// Asks for the next page, then calls `pageRequested(keptId:)`.
        case loadPage
        /// Scrolls to the response, at the top of the screen, to keep it in place.
        case keepInPlace(String)
    }

    private(set) var phase: Phase = .idle
    /// Whether the loader is on screen, as last reported.
    private(set) var loaderOnScreen = false
    /// Changes with the phase: a timer started in a previous phase is ignored.
    private(set) var generation = 0

    /// How long the screen waits, once a page is loaded, before calling `timedOut(generation:canLoad:)`: its responses
    /// are listed by then.
    static let listingTimeout: TimeInterval = 1

    /// How long the screen waits, after a scroll keeping a response in place, before calling
    /// `timedOut(generation:canLoad:)`: longer than a bounce at the top of the scroll view, after which the loader
    /// rests on screen if the scroll was lost.
    static let keepInPlaceTimeout: TimeInterval = 3

    /// The response to keep in place once the page being loaded is listed.
    var keptIdAwaitingListing: String? {
        guard case let .loading(keptId) = phase else { return nil }
        return keptId
    }

    /// Called each time the loader comes to rest on screen, even when it was already reported on screen: it then
    /// moved on it. `canLoad`: whether a page may be asked for.
    mutating func loaderRestedOnScreen(canLoad: Bool) -> Action {
        loaderOnScreen = true
        switch phase {
        case .idle:
            return canLoad ? .loadPage : .none
        case .loading:
            return .none
        case let .keepingInPlace(keptId, _):
            // The loader did not leave the screen: the scroll keeping the response in place was lost while the scroll
            // view moved, or the page is too short to push the loader away. Made again now that the scroll view is at
            // rest, the scroll takes, or leaves the loader where it was until the timeout.
            setPhase(.keepingInPlace(keptId: keptId, timedOut: false))
            return .keepInPlace(keptId)
        }
    }

    /// Called once the loader left the screen. While a response is kept in place, the scroll did take.
    mutating func loaderLeftScreen() {
        loaderOnScreen = false
        if case .keepingInPlace = phase { setPhase(.idle) }
    }

    /// Whether to ask for a page now that it may be asked for: the loader rested on screen before.
    func nextPage(canLoad: Bool) -> Action {
        phase == .idle && loaderOnScreen && canLoad ? .loadPage : .none
    }

    /// Called once the screen asked for a page, with the response at the top of the window then.
    mutating func pageRequested(keptId: String?) {
        setPhase(.loading(keptId: keptId))
    }

    /// Called once the page is listed above `keptId`: the screen scrolls to it to keep it in place.
    mutating func pageListed(keepingInPlace keptId: String) -> Action {
        setPhase(.keepingInPlace(keptId: keptId, timedOut: false))
        return .keepInPlace(keptId)
    }

    /// Called when the page could not be loaded. It is asked for again when the screen asks for it, as the loader
    /// rests on screen again or the window refreshes, rather than at once, which would repeat the error in a loop.
    /// A page whose call failed after the stored responses above the window were listed keeps its response in place.
    mutating func pageFailed() {
        guard case .loading = phase else { return }
        setPhase(.idle)
    }

    /// Called when the response kept in place no longer applies: the window was listed anew.
    mutating func forgetKeptResponse() {
        switch phase {
        case .idle: break
        // The same page: its timeout still ends it.
        case .loading: phase = .loading(keptId: nil)
        case .keepingInPlace: setPhase(.idle)
        }
    }

    /// Called a while after a page is loaded, with the `generation` read when it was asked for, and after each scroll
    /// keeping a response in place, with the one read then. Ignored if something happened meanwhile. A loader still on
    /// screen after the scroll keeping the response in place may still be under the member's finger: the scroll is
    /// made again, and the next page is asked for only if the loader is still there at the next timeout.
    mutating func timedOut(generation: Int, canLoad: Bool) -> Action {
        guard generation == self.generation else { return .none }
        if case let .keepingInPlace(keptId, timedOut: false) = phase, loaderOnScreen {
            setPhase(.keepingInPlace(keptId: keptId, timedOut: true))
            return .keepInPlace(keptId)
        }
        guard phase != .idle else { return .none }
        setPhase(.idle)
        return nextPage(canLoad: canLoad)
    }

    private mutating func setPhase(_ phase: Phase) {
        self.phase = phase
        generation += 1
    }
}
