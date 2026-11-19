//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct MostRecentWindowTests {

    @Test func listsTheNewestFirstFeedOldestAtTheTop() {
        #expect(MostRecentWindow.displayOrder(newestFirst: ["3", "2", "1"]) == ["1", "2", "3"])
    }

    @Test func refreshAsksForTheInitialSizeAtLeast() {
        #expect(MostRecentWindow.refreshSize(listedCount: 0) == MostRecentWindow.initialSize)
        #expect(MostRecentWindow.refreshSize(listedCount: 5) == MostRecentWindow.initialSize)
    }

    @Test func refreshKeepsEveryResponsePagedIn() {
        #expect(MostRecentWindow.refreshSize(listedCount: 120) == 120)
    }

    @Test func followsANewerResponseWhenTheNewestOneWasOnScreen() {
        #expect(MostRecentWindow.followsNewest(previousNewestId: "1", newestId: "2", previousNewestVisible: true))
    }

    @Test func doesNotFollowWhenTheMemberReadsOlderResponses() {
        #expect(!MostRecentWindow.followsNewest(previousNewestId: "1", newestId: "2", previousNewestVisible: false))
    }

    @Test func doesNotFollowWhenTheNewestResponseIsUnchanged() {
        #expect(!MostRecentWindow.followsNewest(previousNewestId: "1", newestId: "1", previousNewestVisible: true))
    }

    @Test func doesNotFollowBeforeAnythingWasListed() {
        #expect(!MostRecentWindow.followsNewest(previousNewestId: nil, newestId: "1", previousNewestVisible: true))
        #expect(!MostRecentWindow.followsNewest(previousNewestId: "1", newestId: nil, previousNewestVisible: true))
    }

    @Test func keepsThePreviousTopRowInPlaceOnceOlderOnesAreInserted() {
        #expect(MostRecentWindow.rowKeptInPlace(previousFirstId: "3", ids: ["1", "2", "3", "4"]) == "3")
    }

    @Test func keepsNothingInPlaceWhenNothingWasInsertedAbove() {
        #expect(MostRecentWindow.rowKeptInPlace(previousFirstId: "1", ids: ["1", "2"]) == nil)
    }

    @Test func keepsNothingInPlaceWhenThePreviousTopRowIsGone() {
        #expect(MostRecentWindow.rowKeptInPlace(previousFirstId: "9", ids: ["1", "2"]) == nil)
        #expect(MostRecentWindow.rowKeptInPlace(previousFirstId: nil, ids: ["1", "2"]) == nil)
    }

    // MARK: - Following the window as it changes

    @Test func aLandingWindowIsScrolledToItsBottom() {
        let step = MostRecentWindow.follow(ids: ["1", "2"], previousNewestId: nil, previousNewestVisible: false,
                                           previousFirstId: nil, landing: true)
        #expect(step == .init(rowKeptInPlace: nil, scrollsToBottom: true))
    }

    @Test func anEmptyLandingWindowIsNotScrolled() {
        let step = MostRecentWindow.follow(ids: [], previousNewestId: nil, previousNewestVisible: false,
                                           previousFirstId: nil, landing: true)
        #expect(step == .init(rowKeptInPlace: nil, scrollsToBottom: false))
    }

    @Test func olderResponsesInsertedAboveKeepTheReadRowInPlaceWithoutScrolling() {
        let step = MostRecentWindow.follow(ids: ["a", "b", "1", "2"], previousNewestId: "2",
                                           previousNewestVisible: false, previousFirstId: "1", landing: false)
        #expect(step == .init(rowKeptInPlace: "1", scrollsToBottom: false))
    }

    @Test func aNewerResponseUnderTheMembersEyesScrollsToTheBottom() {
        let step = MostRecentWindow.follow(ids: ["1", "2", "3"], previousNewestId: "2",
                                           previousNewestVisible: true, previousFirstId: nil, landing: false)
        #expect(step == .init(rowKeptInPlace: nil, scrollsToBottom: true))
    }

    @Test func aPageOfNewerResponsesUnderTheCommentOpenedOnDoesNotScroll() {
        let step = MostRecentWindow.follow(ids: ["1", "2", "3", "4"], previousNewestId: "2",
                                           previousNewestVisible: true, previousFirstId: nil, landing: false,
                                           pagesNewer: true)
        #expect(step == .init(rowKeptInPlace: nil, scrollsToBottom: false))
    }

    @Test func aNewerResponseWhileReadingOlderOnesDoesNotScroll() {
        let step = MostRecentWindow.follow(ids: ["1", "2", "3"], previousNewestId: "2",
                                           previousNewestVisible: false, previousFirstId: nil, landing: false)
        #expect(step == .init(rowKeptInPlace: nil, scrollsToBottom: false))
    }

    @Test func theLaidOutPartStartsAtTheTopOfTheFirstWindowListed() {
        #expect(MostRecentWindow.laidOutStart(ids: ["1", "2", "3"], previousIds: [], previousStart: nil) == "1")
    }

    @Test func nothingIsLaidOutBeforeAnythingIsListed() {
        #expect(MostRecentWindow.laidOutStart(ids: [], previousIds: [], previousStart: nil) == nil)
    }

    @Test func olderPagesInsertedAboveStayOutOfTheLaidOutPart() {
        let window = ids(MostRecentWindow.initialSize)
        #expect(MostRecentWindow.laidOutStart(ids: ["a", "b"] + window, previousIds: window,
                                              previousStart: window[0]) == window[0])
    }

    @Test func anOlderPageInsertedAboveAShortWindowStaysOutOfTheLaidOutPart() {
        // Hidden or deleted responses left fewer than `initialSize` in the window: the response kept in place as the
        // page is inserted still starts the laid out part.
        let window = ids(MostRecentWindow.initialSize - 2)
        let page = (1...MostRecentWindow.olderPageSize).map { "page\($0)" }
        #expect(MostRecentWindow.laidOutStart(ids: page + window, previousIds: window,
                                              previousStart: window[0]) == window[0])
    }

    @Test func theLaidOutPartHoldsTheInitialSizeAtLeast() {
        // The window opened on the few responses stored by a previous visit, then the server's inserted more above.
        let window = ids(MostRecentWindow.initialSize)
        let stored = Array(window.suffix(10))
        #expect(MostRecentWindow.laidOutStart(ids: window, previousIds: stored, previousStart: stored[0]) == window[0])
        #expect(MostRecentWindow.laidOutStart(ids: ["a"] + window, previousIds: window,
                                              previousStart: window[0]) == window[0])
    }

    @Test func aDeletionInTheLaidOutPartLeavesTheOlderPagesLazy() {
        let window = ids(MostRecentWindow.initialSize)
        #expect(MostRecentWindow.laidOutStart(ids: ["a", "b"] + window.dropLast(), previousIds: ["a", "b"] + window,
                                              previousStart: window[0]) == window[0])
    }

    @Test func anOlderResponseBackfilledAboveLazyOnesLeavesThemLazy() {
        // Deletions left fewer than `initialSize` below the start, then a refresh lists one more older response on top.
        let window = ids(MostRecentWindow.initialSize - 2)
        #expect(MostRecentWindow.laidOutStart(ids: ["older", "a", "b"] + window.dropLast(),
                                              previousIds: ["a", "b"] + window, previousStart: window[0]) == window[0])
    }

    @Test func responsesAppendedBelowJoinTheLaidOutPart() {
        #expect(MostRecentWindow.laidOutStart(ids: ["1", "2", "3", "4"], previousIds: ["1", "2", "3"],
                                              previousStart: "1") == "1")
    }

    @Test func aRemovedStartMovesToTheNextResponseOfTheLaidOutPart() {
        // An older page stays listed above: its responses must not join the laid out part.
        let window = ids(MostRecentWindow.initialSize + 1)
        #expect(MostRecentWindow.laidOutStart(ids: ["a"] + window.dropFirst(), previousIds: ["a"] + window,
                                              previousStart: window[0]) == window[1])
    }

    @Test func aWindowListedAnewIsLaidOutFromItsTop() {
        // The window shrinks back once the member sent a response: the older pages and the old start are gone.
        #expect(MostRecentWindow.laidOutStart(ids: ["3", "4", "5"], previousIds: ["a", "1", "2", "3", "4"],
                                              previousStart: "1") == "3")
        #expect(MostRecentWindow.laidOutStart(ids: ["x", "y"], previousIds: ["1", "2"], previousStart: "1") == "x")
    }

    @Test func theRememberedStartSplitsEveryVersionOfTheWindow() {
        let start = MostRecentWindowLaidOutStart()
        let window = ids(MostRecentWindow.initialSize)
        #expect(start.part(in: window, pagesNewer: false).lowerBound == 0)
        #expect(start.part(in: ["a", "b"] + window, pagesNewer: false).lowerBound == 2)
        #expect(start.part(in: ["a", "b"] + window + ["new"], pagesNewer: false).lowerBound == 2)
        start.reset()
        #expect(start.part(in: ["a", "b"] + window, pagesNewer: false).lowerBound == 0)
    }

    @Test func theMostRecentEndIsLaidOutToItsBottom() {
        #expect(MostRecentWindow.laidOutEnd(ids: ["1", "2"], previousIds: [], previousEnd: nil,
                                            pagesNewer: false) == nil)
        #expect(MostRecentWindow.laidOutEnd(ids: ["1", "2", "3"], previousIds: ["1", "2"], previousEnd: nil,
                                            pagesNewer: false) == nil)
    }

    @Test func theWindowAroundTheCommentOpenedOnEndsItsLaidOutPartOnItsNewestResponse() {
        #expect(MostRecentWindow.laidOutEnd(ids: ["1", "2", "3"], previousIds: [], previousEnd: nil,
                                            pagesNewer: true) == "3")
    }

    @Test func newerPagesAppendedBelowStayOutOfTheLaidOutPart() {
        #expect(MostRecentWindow.laidOutEnd(ids: ["1", "2", "3", "4", "5"], previousIds: ["1", "2", "3"],
                                            previousEnd: "3", pagesNewer: true) == "3")
        // The last page, after which the window is the most recent end, stays lazy too.
        #expect(MostRecentWindow.laidOutEnd(ids: ["1", "2", "3", "4", "5"], previousIds: ["1", "2", "3", "4"],
                                            previousEnd: "3", pagesNewer: false) == "3")
    }

    @Test func aWindowOpenedWithoutNewerResponsesDoesNotStopItsPartLater() {
        // A response is never moved out of the laid out part.
        #expect(MostRecentWindow.laidOutEnd(ids: ["1", "2", "3"], previousIds: ["1", "2"], previousEnd: nil,
                                            pagesNewer: true) == nil)
    }

    @Test func aRemovedEndMovesToTheResponseAboveIt() {
        #expect(MostRecentWindow.laidOutEnd(ids: ["1", "2", "4"], previousIds: ["1", "2", "3", "4"],
                                            previousEnd: "3", pagesNewer: true) == "2")
    }

    @Test func aWindowListedAnewEndsItsPartOnItsNewestResponseOnlyWhilePagingNewerOnes() {
        #expect(MostRecentWindow.laidOutEnd(ids: ["x", "y"], previousIds: ["1", "2", "3"], previousEnd: "2",
                                            pagesNewer: false) == nil)
        #expect(MostRecentWindow.laidOutEnd(ids: ["x", "y"], previousIds: ["1", "2", "3"], previousEnd: "2",
                                            pagesNewer: true) == "y")
    }

    @Test func theRememberedPartLeavesOlderAndNewerPagesOut() {
        let part = MostRecentWindowLaidOutStart()
        let window = ids(MostRecentWindow.initialSize + 1)
        #expect(part.part(in: window, pagesNewer: true) == 0..<window.count)
        #expect(part.part(in: ["o1"] + window, pagesNewer: true) == 1..<(window.count + 1))
        #expect(part.part(in: ["o1"] + window + ["n1", "n2"], pagesNewer: false) == 1..<(window.count + 1))
        part.reset()
        #expect(part.part(in: ["a", "b"], pagesNewer: false) == 0..<2)
    }

    @Test func aPartWhoseResponsesWereAllDeletedNeverEndsAboveItsStart() {
        let part = MostRecentWindowLaidOutStart()
        let window = ids(MostRecentWindow.initialSize + 1)
        _ = part.part(in: window, pagesNewer: true)
        _ = part.part(in: ["o1"] + window + ["n1"], pagesNewer: true)
        let range = part.part(in: ["o1", "n1"], pagesNewer: true)
        #expect(range.lowerBound <= range.upperBound)
        #expect(range.upperBound <= 2)
    }

    @Test func theMostRecentEndListedAfterASentResponseIsLaidOutToItsBottom() {
        let part = MostRecentWindowLaidOutStart()
        let window = ids(MostRecentWindow.initialSize + 1)
        _ = part.part(in: window, pagesNewer: true, windowId: "aroundTheComment")
        #expect(part.part(in: window + ["n1", "n2"], pagesNewer: false, windowId: "aroundTheComment")
                == 0..<window.count)
        // The sent response, the newer pages and the end of the previous part are all laid out at once.
        let mostRecentEnd = Array(window.suffix(3)) + ["n1", "n2", "sent"]
        #expect(part.part(in: mostRecentEnd, pagesNewer: false, windowId: "mostRecentEnd")
                == 0..<mostRecentEnd.count)
    }

    private func ids(_ count: Int) -> [String] {
        (1...count).map(String.init)
    }
}
