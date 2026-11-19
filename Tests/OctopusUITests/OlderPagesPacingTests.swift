//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct OlderPagesPacingTests {

    @Test func loadsAPageOnceTheLoaderRestsOnScreen() {
        var pacing = OlderPagesPacing()

        #expect(pacing.loaderRestedOnScreen(canLoad: true) == .loadPage)
    }

    @Test func waitsUntilAPageMayLoad() {
        var pacing = OlderPagesPacing()

        #expect(pacing.loaderRestedOnScreen(canLoad: false) == .none)
        // The screen reached its most recent end since: the loader is still on screen.
        #expect(pacing.nextPage(canLoad: true) == .loadPage)
    }

    @Test func doesNotLoadOnceTheLoaderLeftTheScreen() {
        var pacing = OlderPagesPacing()
        _ = pacing.loaderRestedOnScreen(canLoad: false)

        pacing.loaderLeftScreen()

        #expect(pacing.nextPage(canLoad: true) == .none)
    }

    @Test func loadsOnePageAtATime() {
        var pacing = loadingAPage()

        #expect(pacing.loaderRestedOnScreen(canLoad: true) == .none)
        #expect(pacing.nextPage(canLoad: true) == .none)
    }

    @Test func keepsTheResponseAtTheTopOfTheWindowInPlaceOnceThePageIsListed() {
        var pacing = loadingAPage(keptId: "1")

        #expect(pacing.keptIdAwaitingListing == "1")
        #expect(pacing.pageListed(keepingInPlace: "1") == .keepInPlace("1"))
        #expect(pacing.keptIdAwaitingListing == nil)
    }

    @Test func endsThePageOnceTheLoaderLeftTheScreen() {
        var pacing = keepingInPlace("1")

        pacing.loaderLeftScreen()

        #expect(pacing.phase == .idle)
        // Back on screen later, when the member scrolled up to it: the next page loads.
        #expect(pacing.loaderRestedOnScreen(canLoad: true) == .loadPage)
    }

    // The scroll keeping the response in place was lost while the scroll view moved: the loader did not leave.
    @Test func keepsTheResponseInPlaceAgainEachTimeTheLoaderRestsOnScreen() {
        var pacing = keepingInPlace("1")

        #expect(pacing.loaderRestedOnScreen(canLoad: true) == .keepInPlace("1"))
        // Still under the member's finger: lost again.
        #expect(pacing.loaderRestedOnScreen(canLoad: true) == .keepInPlace("1"))
        #expect(pacing.phase == .keepingInPlace(keptId: "1", timedOut: false))
    }

    // Held past the top of the scroll view: the loader moves without resting, and the scroll is lost.
    @Test func keepsTheResponseInPlaceAgainWhenTheScrollTimesOutWithTheLoaderOnScreen() {
        var pacing = keepingInPlace("1")
        _ = pacing.loaderRestedOnScreen(canLoad: true)

        #expect(pacing.timedOut(generation: pacing.generation, canLoad: true) == .keepInPlace("1"))
        #expect(pacing.phase == .keepingInPlace(keptId: "1", timedOut: true))
    }

    // A page too short to push the loader away: the scroll made again leaves the loader where it was, unreported.
    @Test func loadsTheNextPageWhenTheScrollTimesOutTwiceWithTheLoaderOnScreen() {
        var pacing = keepingInPlace("1")
        _ = pacing.loaderRestedOnScreen(canLoad: true)
        _ = pacing.timedOut(generation: pacing.generation, canLoad: true)

        #expect(pacing.timedOut(generation: pacing.generation, canLoad: true) == .loadPage)
        #expect(pacing.phase == .idle)
    }

    @Test func endsThePageWithoutLoadingWhenTheScrollTimesOutWithTheLoaderOffScreen() {
        var pacing = OlderPagesPacing()
        pacing.pageRequested(keptId: "1")
        _ = pacing.pageListed(keepingInPlace: "1")
        let generation = pacing.generation

        #expect(pacing.timedOut(generation: generation, canLoad: true) == .none)
        #expect(pacing.phase == .idle)
    }

    @Test func waitsForTheLastScrollKeepingTheResponseInPlace() {
        var pacing = keepingInPlace("1")
        let firstScroll = pacing.generation

        _ = pacing.loaderRestedOnScreen(canLoad: true)

        #expect(pacing.timedOut(generation: firstScroll, canLoad: true) == .none)
        #expect(pacing.phase == .keepingInPlace(keptId: "1", timedOut: false))
    }

    // The feed ignored the call, or the page only held responses listed already.
    @Test func loadsTheNextPageWhenNothingWasListedAboveTheWindowInTime() {
        var pacing = loadingAPage()
        let generation = pacing.generation

        #expect(pacing.timedOut(generation: generation, canLoad: true) == .loadPage)
    }

    @Test func ignoresTheTimeoutOfAPageListedMeanwhile() {
        var pacing = loadingAPage(keptId: "1")
        let request = pacing.generation
        _ = pacing.pageListed(keepingInPlace: "1")

        #expect(pacing.timedOut(generation: request, canLoad: true) == .none)
        #expect(pacing.phase == .keepingInPlace(keptId: "1", timedOut: false))
    }

    @Test func asksForAFailedPageAgainOnlyWhenAskedTo() {
        var pacing = loadingAPage()

        pacing.pageFailed()

        #expect(pacing.phase == .idle)
        #expect(pacing.nextPage(canLoad: true) == .loadPage)
    }

    // Offline, the stored responses above the window are listed before the call is reported as failed.
    @Test func keepsTheResponseInPlaceWhenThePageFailsAfterListingStoredResponses() {
        var pacing = keepingInPlace("1")
        let listing = pacing.generation

        pacing.pageFailed()

        #expect(pacing.phase == .keepingInPlace(keptId: "1", timedOut: false))
        #expect(pacing.timedOut(generation: listing, canLoad: true) == .keepInPlace("1"))
    }

    @Test func forgetsTheResponseToKeepInPlaceWhenTheWindowIsListedAnew() {
        var loading = loadingAPage(keptId: "1")
        loading.forgetKeptResponse()
        #expect(loading.keptIdAwaitingListing == nil)
        #expect(loading.phase == .loading(keptId: nil))

        var keeping = keepingInPlace("1")
        keeping.forgetKeptResponse()
        #expect(keeping.phase == .idle)
    }

    // A response sent while a page loads lists the window anew: the page must still end.
    @Test func endsThePageLoadingWhenTheResponseToKeepInPlaceWasForgotten() {
        var pacing = loadingAPage(keptId: "1")
        let request = pacing.generation

        pacing.forgetKeptResponse()

        #expect(pacing.timedOut(generation: request, canLoad: true) == .loadPage)
        #expect(pacing.phase == .idle)
    }

    private func loadingAPage(keptId: String? = "1") -> OlderPagesPacing {
        var pacing = OlderPagesPacing()
        _ = pacing.loaderRestedOnScreen(canLoad: true)
        pacing.pageRequested(keptId: keptId)
        return pacing
    }

    private func keepingInPlace(_ keptId: String) -> OlderPagesPacing {
        var pacing = loadingAPage(keptId: keptId)
        _ = pacing.pageListed(keepingInPlace: keptId)
        return pacing
    }
}
