//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import OctopusCore
@testable import OctopusUI

@MainActor
final class ReactionsListViewModelTests: XCTestCase {

    /// Serves scripted pages and records what was asked, so paging can be asserted without a backend.
    private final class FetchRecorder {
        struct Call: Equatable {
            let kind: ReactionKind?
            let cursor: String?
        }

        private(set) var calls = [Call]()
        /// Results to return, in call order. An entry may be an error instead of a page.
        var results = [Result<ReactionsPage, ServerCallError>]()

        func fetch(kind: ReactionKind?, cursor: String?) throws(ServerCallError) -> ReactionsPage {
            calls.append(Call(kind: kind, cursor: cursor))
            guard !results.isEmpty else { return ReactionsPage(reactions: [], nextCursor: nil) }
            switch results.removeFirst() {
            case let .success(page): return page
            case let .failure(error): throw error
            }
        }
    }

    private func makeViewModel(recorder: FetchRecorder, reactions: [ReactionCount])
    -> ReactionsListViewModel {
        let manager = ReactionsListManager(fetch: { _, kind, cursor, _ in
            try recorder.fetch(kind: kind, cursor: cursor)
        })
        return ReactionsListViewModel(manager: manager, contentId: "post-1", reactions: reactions)
    }

    private func page(_ names: [String], nextCursor: String?) -> ReactionsPage {
        ReactionsPage(
            reactions: names.map { ProfileReaction(profile: .init(uuid: $0, nickname: $0), kind: .heart) },
            nextCursor: nextCursor)
    }

    // MARK: - Tabs

    func testTabsAreAllPlusEachNonEmptyKindInBackendOrder() {
        let viewModel = makeViewModel(recorder: FetchRecorder(), reactions: [
            ReactionCount(reactionKind: .joy, count: 9),
            ReactionCount(reactionKind: .heart, count: 4),
            ReactionCount(reactionKind: .cry, count: 0)
        ])

        // The backend already sorts counters by volume, so the tab order is its order; a kind nobody
        // used gets no tab at all.
        XCTAssertEqual(viewModel.tabs, [.all, .kind(.joy), .kind(.heart)])
    }

    func testKindTabsAreOrderedByVolume() {
        let viewModel = makeViewModel(recorder: FetchRecorder(), reactions: [
            ReactionCount(reactionKind: .joy, count: 3),
            ReactionCount(reactionKind: .mouthOpen, count: 7),
            ReactionCount(reactionKind: .heart, count: 5)
        ])

        // More 😮 than 😂 puts 😮 first, whatever order the counters arrived in.
        XCTAssertEqual(viewModel.tabs, [.all, .kind(.mouthOpen), .kind(.heart), .kind(.joy)])
    }

    func testEqualVolumesKeepTheBackendOrder() {
        let viewModel = makeViewModel(recorder: FetchRecorder(), reactions: [
            ReactionCount(reactionKind: .joy, count: 4),
            ReactionCount(reactionKind: .heart, count: 4),
            ReactionCount(reactionKind: .clap, count: 9)
        ])

        // On a tie the spec orders by most recent reaction, which only the backend can express — through
        // the order it sends the counters in. Sorting must not scramble it.
        XCTAssertEqual(viewModel.tabs, [.all, .kind(.clap), .kind(.joy), .kind(.heart)])
    }

    func testCountsComeFromTheCountersBeforeAnyFetch() {
        let viewModel = makeViewModel(recorder: FetchRecorder(), reactions: [
            ReactionCount(reactionKind: .joy, count: 9),
            ReactionCount(reactionKind: .heart, count: 4)
        ])

        XCTAssertEqual(viewModel.counts[.kind(.joy)], 9)
        XCTAssertEqual(viewModel.counts[.kind(.heart)], 4)
        // The All tab is labelled without a count, so it must not carry one.
        XCTAssertNil(viewModel.counts[.all])
    }

    func testASingleKindGetsNoAllTab() {
        let viewModel = makeViewModel(recorder: FetchRecorder(), reactions: [
            ReactionCount(reactionKind: .joy, count: 2),
            ReactionCount(reactionKind: .heart, count: 0)
        ])

        // An All tab would list exactly the same people as the only kind's tab.
        XCTAssertEqual(viewModel.tabs, [.kind(.joy)])
        XCTAssertEqual(viewModel.selectedTab, .kind(.joy))
    }

    func testAllIsSelectedFirstWhenSeveralKinds() {
        let viewModel = makeViewModel(recorder: FetchRecorder(), reactions: [
            ReactionCount(reactionKind: .joy, count: 2),
            ReactionCount(reactionKind: .heart, count: 1)
        ])

        XCTAssertEqual(viewModel.selectedTab, .all)
    }

    func testNoReactionAtAllStillHasASelectableTab() {
        let viewModel = makeViewModel(recorder: FetchRecorder(), reactions: [])

        // Not reachable from the UI, but `selectedTab` indexes into `tabs`: an empty one would trap.
        XCTAssertEqual(viewModel.tabs, [.all])
        XCTAssertEqual(viewModel.selectedTab, .all)
    }

    // MARK: - Paging

    func testFirstPageOfTheAllTabAsksForEveryKindWithoutCursor() async {
        let recorder = FetchRecorder()
        recorder.results = [.success(page(["a", "b"], nextCursor: nil))]
        let viewModel = makeViewModel(recorder: recorder,
                                      reactions: [ReactionCount(reactionKind: .joy, count: 2)])

        await viewModel.loadFirstPageIfNeeded(tab: .all)

        XCTAssertEqual(recorder.calls, [.init(kind: nil, cursor: nil)])
        let content = viewModel.content(for: .all)
        XCTAssertEqual(content.reactions.count, 2)
        XCTAssertFalse(content.canLoadMore)
        XCTAssertFalse(content.isLoadingFirstPage)
    }

    func testKindTabFiltersOnItsKind() async {
        let recorder = FetchRecorder()
        recorder.results = [.success(page(["a"], nextCursor: nil))]
        let viewModel = makeViewModel(recorder: recorder,
                                      reactions: [ReactionCount(reactionKind: .joy, count: 1)])

        await viewModel.loadFirstPageIfNeeded(tab: .kind(.joy))

        XCTAssertEqual(recorder.calls, [.init(kind: .joy, cursor: nil)])
    }

    func testLoadMoreAppendsAndForwardsTheCursor() async {
        let recorder = FetchRecorder()
        recorder.results = [
            .success(page(["a"], nextCursor: "c1")),
            .success(page(["b"], nextCursor: nil))
        ]
        let viewModel = makeViewModel(recorder: recorder, reactions: [])

        await viewModel.loadFirstPageIfNeeded(tab: .all)
        XCTAssertTrue(viewModel.content(for: .all).canLoadMore)
        await viewModel.loadMore(tab: .all)

        XCTAssertEqual(recorder.calls, [.init(kind: nil, cursor: nil), .init(kind: nil, cursor: "c1")])
        let content = viewModel.content(for: .all)
        XCTAssertEqual(content.reactions.map { $0.profile?.uuid }, ["a", "b"])
        // Cursor exhausted: paging must stop, or the end-of-list sentinel would loop forever.
        XCTAssertFalse(content.canLoadMore)
    }

    func testFirstPageIsNotFetchedTwice() async {
        let recorder = FetchRecorder()
        recorder.results = [.success(page(["a"], nextCursor: nil))]
        let viewModel = makeViewModel(recorder: recorder, reactions: [])

        await viewModel.loadFirstPageIfNeeded(tab: .all)
        // Coming back to a tab already loaded must show what it has, not refetch it.
        await viewModel.loadFirstPageIfNeeded(tab: .all)

        XCTAssertEqual(recorder.calls.count, 1)
    }

    func testLoadMoreDoesNothingWithoutACursor() async {
        let recorder = FetchRecorder()
        recorder.results = [.success(page(["a"], nextCursor: nil))]
        let viewModel = makeViewModel(recorder: recorder, reactions: [])

        await viewModel.loadFirstPageIfNeeded(tab: .all)
        await viewModel.loadMore(tab: .all)

        XCTAssertEqual(recorder.calls.count, 1)
    }

    func testTabsPageIndependently() async {
        let recorder = FetchRecorder()
        recorder.results = [
            .success(page(["all-1"], nextCursor: "all-c")),
            .success(page(["joy-1"], nextCursor: nil))
        ]
        let viewModel = makeViewModel(recorder: recorder,
                                      reactions: [ReactionCount(reactionKind: .joy, count: 1)])

        await viewModel.loadFirstPageIfNeeded(tab: .all)
        await viewModel.loadFirstPageIfNeeded(tab: .kind(.joy))

        // The joy tab starts from its own first page, and the All tab keeps its own cursor.
        XCTAssertEqual(recorder.calls, [.init(kind: nil, cursor: nil), .init(kind: .joy, cursor: nil)])
        XCTAssertEqual(viewModel.content(for: .all).nextCursor, "all-c")
        XCTAssertNil(viewModel.content(for: .kind(.joy)).nextCursor)
    }

    // MARK: - Errors

    func testFailedFirstPageSurfacesAMessageAndCanBeRetried() async {
        let recorder = FetchRecorder()
        recorder.results = [.failure(.noNetwork), .success(page(["a"], nextCursor: nil))]
        let viewModel = makeViewModel(recorder: recorder, reactions: [])

        await viewModel.loadFirstPageIfNeeded(tab: .all)
        XCTAssertEqual(viewModel.content(for: .all).error, .localizationKey("Error.NoNetwork"))
        XCTAssertFalse(viewModel.content(for: .all).isLoadingFirstPage)

        await viewModel.retry(tab: .all)

        // Retrying an empty tab reruns the first page rather than paging from nowhere.
        XCTAssertEqual(recorder.calls, [.init(kind: nil, cursor: nil), .init(kind: nil, cursor: nil)])
        XCTAssertNil(viewModel.content(for: .all).error)
        XCTAssertEqual(viewModel.content(for: .all).reactions.count, 1)
    }

    func testFailedNextPageKeepsWhatWasLoadedAndResumesFromTheCursor() async {
        let recorder = FetchRecorder()
        recorder.results = [
            .success(page(["a"], nextCursor: "c1")),
            .failure(.other(NSError(domain: "test", code: 1))),
            .success(page(["b"], nextCursor: nil))
        ]
        let viewModel = makeViewModel(recorder: recorder, reactions: [])

        await viewModel.loadFirstPageIfNeeded(tab: .all)
        await viewModel.loadMore(tab: .all)

        XCTAssertEqual(viewModel.content(for: .all).error, .localizationKey("Error.Unknown"))
        // The page already loaded must survive the failure.
        XCTAssertEqual(viewModel.content(for: .all).reactions.count, 1)
        // An error suspends paging, so the sentinel cannot spin on the failure.
        XCTAssertFalse(viewModel.content(for: .all).canLoadMore)

        await viewModel.retry(tab: .all)

        XCTAssertEqual(recorder.calls.last, .init(kind: nil, cursor: "c1"))
        XCTAssertEqual(viewModel.content(for: .all).reactions.map { $0.profile?.uuid }, ["a", "b"])
        XCTAssertNil(viewModel.content(for: .all).error)
    }
}
