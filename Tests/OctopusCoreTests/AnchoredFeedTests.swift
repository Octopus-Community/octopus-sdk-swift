//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusRemoteClient
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// A window of a feed opened on an item: the items around it, paged towards both ends, stored apart from the feed.
class AnchoredFeedTests: XCTestCase {

    private var injector: Injector!
    private var mockOctoService: MockOctoService!
    private var mockFeedService: MockFeedService!
    private var networkMonitor: MockNetworkMonitor!
    private var feedItemInfosDatabase: FeedItemInfosDatabase!
    private var postFeedManager: FeedManager<Post, Comment>!

    override func setUp() {
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .blockedUserIdsProvider)

        let remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        mockOctoService = (remoteClient.octoService as! MockOctoService)
        mockFeedService = (remoteClient.feedService as! MockFeedService)
        networkMonitor = (injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor)
        feedItemInfosDatabase = injector.getInjected(identifiedBy: Injected.feedItemInfosDatabase)

        postFeedManager = PostsFeedManager.factory(injector: injector)
    }

    func testOpensOnTheWindowAroundTheItem() async throws {
        let feed = try await anchoredFeed()

        XCTAssertEqual(mockFeedService.initializeFeedFeedIds, ["1"])
        XCTAssertEqual(mockFeedService.initializeFeedAnchorItemIds, ["4"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["3", "4", "5"] }
        try await assertWithTimeout { await feed.anchorItemId == "4" }
        try await assertWithTimeout { await feed.hasNewerData }
        try await assertWithTimeout { await feed.hasMoreData }
    }

    /// The window is stored under a key of its own: the feed it opens from keeps the items it stores and lists.
    func testTheWindowIsNotStoredUnderTheFeedItOpensFrom() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with { $0.items = feedItems(["1", "2"]) })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)

        let window = await feed.makeWindow(anchoredOn: "4")
        mockFeedService.injectNextInitializeFeed(windowAroundFour())
        injectBatchItems(["3", "4", "5"])
        let isAnchored = try await window.openWindow(pageSize: 3)

        XCTAssertTrue(isAnchored)
        XCTAssertEqual(mockFeedService.initializeFeedFeedIds, ["1", "1"])
        let windowId = await window.id
        XCTAssertNotEqual(windowId, "1")
        try await assertStoredItemIds(feedId: "1", ["1", "2"])
        try await assertStoredItemIds(feedId: windowId, ["3", "4", "5"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
        try await assertWithTimeout { await window.items?.map(\.uuid) == ["3", "4", "5"] }
    }

    func testTwoWindowsOfAFeedAreIndependent() async throws {
        let firstWindow = try await anchoredFeed()

        let secondWindow = await Feed(id: "1", feedManager: postFeedManager).makeWindow(anchoredOn: "8")
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = feedItems(["7", "8", "9"])
            $0.nextPageCursor = "older8"
            $0.previousPageCursor = "newer8"
        })
        injectBatchItems(["7", "8", "9"])
        try await secondWindow.openWindow(pageSize: 3)

        try await assertWithTimeout { await secondWindow.items?.map(\.uuid) == ["7", "8", "9"] }
        try await assertWithTimeout { await firstWindow.items?.map(\.uuid) == ["3", "4", "5"] }
        try await assertStoredItemIds(feedId: await firstWindow.id, ["3", "4", "5"])
    }

    func testAReleasedWindowDeletesWhatItStores() async throws {
        var window: Feed<Post, Comment>? = try await anchoredFeed()
        let windowId = await window?.id ?? ""
        try await assertStoredItemIds(feedId: windowId, ["3", "4", "5"])

        window = nil

        try await assertWithTimeout { try await self.storedItemIds(feedId: windowId).isEmpty }
    }

    /// The windows of a launch that ended are no longer listed by any screen.
    func testTheWindowsOfAPreviousLaunchAreDeletedOnStart() async throws {
        let previousLaunchWindowId = "1\(FeedWindowKey.marker)previousLaunch.window"
        let currentLaunchWindowId = FeedWindowKey.make(serverFeedId: "1")
        for feedId in [previousLaunchWindowId, currentLaunchWindowId, "1"] {
            try await feedItemInfosDatabase.upsert(
                feedItemInfos: [FeedItemInfo(feedId: feedId, itemId: "item", updateDate: Date(), featuredChildId: nil)],
                feedId: feedId)
        }

        _ = PostsFeedManager.factory(injector: injector)

        try await assertWithTimeout { try await self.storedItemIds(feedId: previousLaunchWindowId).isEmpty }
        try await assertStoredItemIds(feedId: currentLaunchWindowId, ["item"])
        try await assertStoredItemIds(feedId: "1", ["item"])
    }

    func testListsTheFirstPageWhenTheServerCannotOpenOnTheItem() async throws {
        let feed = await Feed(id: "1", feedManager: postFeedManager).makeWindow(anchoredOn: "9")
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = [.with { $0.octoObjectID = "1" }, .with { $0.octoObjectID = "2" }]
            $0.previousPageCursor = "newer"
        })
        injectBatchItems(["1", "2"])

        let isAnchored = try await feed.openWindow(pageSize: 2)

        XCTAssertFalse(isAnchored)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
        try await assertWithTimeout { await feed.anchorItemId == nil }
        try await assertWithTimeout { await !feed.hasNewerData }
    }

    func testOnlyAWindowOpensOnAnItem() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        let isAnchored = try await feed.openWindow(pageSize: 3)

        XCTAssertFalse(isAnchored)
        XCTAssertEqual(mockFeedService.initializeFeedAnchorItemIds, [])
    }

    func testNewerPagesAreListedBeforeTheWindowClosestFirstUntilTheStartOfTheFeed() async throws {
        let feed = try await anchoredFeed()

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = [.with { $0.octoObjectID = "2" }]
            $0.nextPageCursor = "newer2"
        })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5"] }
        try await assertWithTimeout { await feed.anchorItemId == "4" }
        try await assertWithTimeout { await feed.hasNewerData }

        // The page comes closest first: "1", the first item of the feed, comes last.
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = [.with { $0.octoObjectID = "1b" }, .with { $0.octoObjectID = "1" }]
        })
        injectBatchItems(["1b", "1"])
        try await feed.loadNewerItems()

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "1b", "2", "3", "4", "5"] }
        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["newer", "newer2"])
        try await assertWithTimeout { await feed.anchorItemId == nil }
        try await assertWithTimeout { await !feed.hasNewerData }
        try await assertWithTimeout { await feed.hasMoreData }
    }

    /// A page could hand back a cursor forever without items: the loader would ask for it again and again.
    func testAnEmptyNewerPageEndsTheWindow() async throws {
        let feed = try await anchoredFeed()

        mockFeedService.injectNextGetNextFeedPage(.with { $0.nextPageCursor = "newer2" })
        try await feed.loadNewerItems()
        try await feed.loadNewerItems()

        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["newer"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["3", "4", "5"] }
        try await assertWithTimeout { await feed.anchorItemId == nil }
        try await assertWithTimeout { await !feed.hasNewerData }
    }

    func testTheWindowIsAskedForAtMostAServerPage() async throws {
        let feed = await Feed(id: "1", feedManager: postFeedManager).makeWindow(anchoredOn: "4")
        mockFeedService.injectNextInitializeFeed(windowAroundFour())
        injectBatchItems(["3", "4", "5"])

        try await feed.openWindow(pageSize: 420)

        XCTAssertEqual(mockFeedService.initializeFeedPageSizes, [100])
    }

    func testAFailedNewerPageKeepsItsCursor() async throws {
        let feed = try await anchoredFeed()

        networkMonitor.connectionAvailable = false
        do {
            try await feed.loadNewerItems()
            XCTFail("Expected .noNetwork")
        } catch ServerCallError.noNetwork {
            // expected
        } catch {
            XCTFail("Expected .noNetwork, got \(error)")
        }
        try await assertWithTimeout { await feed.hasNewerData }

        networkMonitor.connectionAvailable = true
        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "2" }] })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()

        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["newer"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5"] }
    }

    /// The page's items are fetched before it is stored: the stored window still matches the cursor kept.
    func testANewerPageWhoseItemsFailToLoadIsNotStored() async throws {
        let feed = try await anchoredFeed()

        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "2" }] })
        // No batch response: fetching the item "2" fails.
        do {
            try await feed.loadNewerItems()
            XCTFail("Expected an error")
        } catch {
            // expected
        }
        try await assertStoredItemIds(feedId: await feed.id, ["3", "4", "5"])
        try await assertWithTimeout { await feed.hasNewerData }

        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "2" }] })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()

        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["newer", "newer"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5"] }
    }

    func testPollingTheFirstPageDoesNothingWhileAnchored() async throws {
        let feed = try await anchoredFeed()

        try await feed.refreshNewestItems(pageSize: 3)

        XCTAssertEqual(mockFeedService.initializeFeedAnchorItemIds, ["4"])
        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, [])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["3", "4", "5"] }
        try await assertWithTimeout { await feed.anchorItemId == "4" }
    }

    func testOlderThenNewerPagesAreListedOnEachSideOfTheWindow() async throws {
        let feed = try await anchoredFeed()

        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "6" }] })
        injectBatchItems(["6"])
        try await feed.loadPreviousItems(pageSize: 1)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["3", "4", "5", "6"] }

        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "2" }] })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()

        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["older", "newer"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5", "6"] }
        try await assertWithTimeout { await !feed.hasMoreData }
        try await assertWithTimeout { await !feed.hasNewerData }
    }

    func testAWindowReachingTheFirstItemIsTheFirstPage() async throws {
        let feed = await Feed(id: "1", feedManager: postFeedManager).makeWindow(anchoredOn: "2")
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = feedItems(["1", "2", "3"])
            $0.nextPageCursor = "older"
        })
        injectBatchItems(["1", "2", "3"])

        let isAnchored = try await feed.openWindow(pageSize: 3)

        XCTAssertTrue(isAnchored)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3"] }
        try await assertWithTimeout { await feed.anchorItemId == nil }
        try await assertWithTimeout { await !feed.hasNewerData }
        try await assertWithTimeout { await feed.hasMoreData }
    }

    /// The window belongs to the screen that opened on the item: refreshing it lists it again, not the first page.
    func testRefreshListsTheWindowAgainAfterNewerPages() async throws {
        let feed = try await anchoredFeed()
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = [.with { $0.octoObjectID = "2" }]
            $0.nextPageCursor = "newer2"
        })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5"] }

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = feedItems(["2", "3", "4", "5"])
            $0.nextPageCursor = "older"
            $0.previousPageCursor = "newer2"
        })
        try await feed.refresh(pageSize: 4)

        XCTAssertEqual(mockFeedService.initializeFeedAnchorItemIds, ["4", "4"])
        XCTAssertEqual(mockFeedService.initializeFeedFeedIds, ["1", "1"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5"] }
        try await assertWithTimeout { await feed.anchorItemId == "4" }
        try await assertWithTimeout { await feed.hasNewerData }
    }

    func testRefreshListsTheFirstPageOnceTheWindowReachedIt() async throws {
        let feed = try await anchoredFeed()
        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "2" }] })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()
        try await assertWithTimeout { await feed.anchorItemId == nil }

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = feedItems(["1", "2", "3"])
            $0.nextPageCursor = "older"
        })
        injectBatchItems(["1"])
        try await feed.refresh(pageSize: 3)

        XCTAssertEqual(mockFeedService.initializeFeedAnchorItemIds, ["4", nil])
        XCTAssertEqual(mockFeedService.initializeFeedFeedIds, ["1", "1"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3"] }
        try await assertStoredItemIds(feedId: await feed.id, ["1", "2", "3"])
        try await assertStoredItemIds(feedId: "1", [])
    }

    func testAFailedRefreshKeepsTheWindowAndItsNewerPages() async throws {
        let feed = try await anchoredFeed()

        networkMonitor.connectionAvailable = false
        do {
            try await feed.refresh(pageSize: 3)
            XCTFail("Expected .noNetwork")
        } catch ServerCallError.noNetwork {
            // expected
        } catch {
            XCTFail("Expected .noNetwork, got \(error)")
        }
        try await assertWithTimeout { await feed.anchorItemId == "4" }
        try await assertWithTimeout { await feed.hasNewerData }

        networkMonitor.connectionAvailable = true
        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "2" }] })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()

        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["newer"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5"] }
    }

    /// The window's items are fetched before it is stored again: the stored window still matches its cursors.
    func testARefreshWhoseItemsFailToLoadKeepsTheStoredWindow() async throws {
        let feed = try await anchoredFeed()

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = feedItems(["2", "3", "4", "5"])
            $0.nextPageCursor = "older2"
            $0.previousPageCursor = "newer2"
        })
        // No batch response: fetching the item "2" fails.
        do {
            try await feed.refresh(pageSize: 4)
            XCTFail("Expected an error")
        } catch {
            // expected
        }

        try await assertStoredItemIds(feedId: await feed.id, ["3", "4", "5"])
        try await assertWithTimeout { await feed.anchorItemId == "4" }
        try await assertWithTimeout { await feed.hasNewerData }

        mockFeedService.injectNextGetNextFeedPage(.with { $0.items = [.with { $0.octoObjectID = "2" }] })
        injectBatchItems(["2"])
        try await feed.loadNewerItems()
        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["newer"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["2", "3", "4", "5"] }
    }

    /// The first page's items are fetched before it is stored: the stored feed still matches its cursors.
    func testAFullRefreshWhoseItemsFailToLoadKeepsTheStoredFeed() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with { $0.items = feedItems(["1", "2"]) })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)

        mockFeedService.injectNextInitializeFeed(.with { $0.items = feedItems(["0", "1", "2"]) })
        // No batch response: fetching the item "0" fails.
        do {
            try await feed.refresh(pageSize: 3)
            XCTFail("Expected an error")
        } catch {
            // expected
        }

        try await assertStoredItemIds(feedId: "1", ["1", "2"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
    }

    /// The newest page's items are fetched before it is merged into the stored feed: the stored feed stays as it was.
    func testANewestPageWhoseItemsFailToLoadKeepsTheStoredFeed() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = feedItems(["1", "2"])
            $0.nextPageCursor = "older"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = feedItems(["0", "1"])
            $0.nextPageCursor = "older"
        })
        // No batch response: fetching the item "0" fails.
        do {
            try await feed.refreshNewestItems(pageSize: 2)
            XCTFail("Expected an error")
        } catch {
            // expected
        }

        try await assertStoredItemIds(feedId: "1", ["1", "2"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
    }

    /// A window of the feed "1" opened on "4", its window "3", "4", "5" between a newer and an older page.
    private func anchoredFeed() async throws -> Feed<Post, Comment> {
        let feed = await Feed(id: "1", feedManager: postFeedManager).makeWindow(anchoredOn: "4")
        mockFeedService.injectNextInitializeFeed(windowAroundFour())
        injectBatchItems(["3", "4", "5"])
        let isAnchored = try await feed.openWindow(pageSize: 3)
        XCTAssertTrue(isAnchored)
        return feed
    }

    private func assertStoredItemIds(feedId: String, _ expected: [String], line: UInt = #line) async throws {
        let stored = try await storedItemIds(feedId: feedId)
        XCTAssertEqual(stored, expected, line: line)
    }

    private func storedItemIds(feedId: String) async throws -> [String] {
        try await feedItemInfosDatabase.feedItemInfos(feedId: feedId, pageSize: 0, lastPageIdx: 0).map(\.itemId)
    }

    private func windowAroundFour() -> Com_Octopuscommunity_GetFeedPageResponse {
        .with {
            $0.items = feedItems(["3", "4", "5"])
            $0.nextPageCursor = "older"
            $0.previousPageCursor = "newer"
        }
    }

    private func feedItems(_ ids: [String]) -> [Com_Octopuscommunity_FeedItemInfo] {
        ids.map { id in .with { $0.octoObjectID = id } }
    }

    private func injectBatchItems(_ items: [String]) {
        mockOctoService.injectNextGetBatchResponse(.with {
            $0.responses = items.map { itemId in
                .with {
                    $0.octoObjectID = itemId
                    $0.octoObject = .with {
                        $0.createdAt = 0
                        $0.id = itemId
                        $0.parentID = ""
                        $0.createdBy = .with {
                            $0.profileID = "authorId"
                            $0.nickname = "me"
                        }
                        $0.content = .with {
                            $0.post = .with {
                                $0.text = "title\(itemId)"
                            }
                        }
                    }
                }
            }
        })
    }
}
