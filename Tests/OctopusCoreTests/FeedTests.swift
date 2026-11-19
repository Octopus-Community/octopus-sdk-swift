//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
@testable import OctopusRemoteClient
import OctopusGrpcModels
import OctopusDependencyInjection
import SwiftProtobuf
@testable import OctopusCore

class FeedTests: XCTestCase {

    private var mockOctoService: MockOctoService!
    private var mockFeedService: MockFeedService!
    private var postsDatabase: PostsDatabase!
    private var feedsDatabase: FeedItemInfosDatabase!
    private var postFeedManager: FeedManager<Post, Comment>!
    private var networkMonitor: MockNetworkMonitor!
    private var blockedUserIdsProvider: MockBlockedUserIdsProvider!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
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
        postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        feedsDatabase = injector.getInjected(identifiedBy: Injected.feedItemInfosDatabase)
        networkMonitor = (injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor)
        blockedUserIdsProvider = (injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider) as! MockBlockedUserIdsProvider)

        postFeedManager = PostsFeedManager.factory(injector: injector)
    }

    @MainActor
    func testFeedWhenNoValues() async throws {
        let expectation1 = XCTestExpectation(description: "Items empty")
        let expectation2 = XCTestExpectation(description: "Items uuids are ['1', '2']")
        let expectation3 = XCTestExpectation(description: "Items uuids are ['1', '2', '3', '4']")
        let expectation4 = XCTestExpectation(description: "Items uuids are ['1', '2', '3', '4', '5', '6']")
        let expectation5 = XCTestExpectation(description: "Items uuids are ['1', '2', '3', '4', '5', '6', '7']")
        let feed = Feed(id: "1", feedManager: postFeedManager)

        await feed.populateWithLocalData(pageSize: 2)

        feed.$items
            .sink { items in
                guard let items else { return }
                if items.isEmpty {
                    expectation1.fulfill()
                } else if items.map(\.uuid) == ["1", "2"] {
                    expectation2.fulfill()
                } else if items.map(\.uuid) == ["1", "2", "3", "4"] {
                    expectation3.fulfill()
                } else if items.map(\.uuid) == ["1", "2", "3", "4", "5", "6"] {
                    expectation4.fulfill()
                } else if items.map(\.uuid) == ["1", "2", "3", "4", "5", "6", "7"] {
                    expectation5.fulfill()
                }
            }.store(in: &storage)
        await fulfillment(of: [expectation1], timeout: 5)

        // initial refresh will ask for the feed item infos and the items since they are not in the db
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = [
                .with { $0.octoObjectID = "1" },
                .with { $0.octoObjectID = "2" },
                .with { $0.octoObjectID = "3" },
                .with { $0.octoObjectID = "4" },
                .with { $0.octoObjectID = "5" },
            ]
            $0.nextPageCursor = "page2"
        })

        injectBatchItems(["1", "2"])

        try await feed.refresh(pageSize: 2)

        await fulfillment(of: [expectation2], timeout: 5)

        // Loading previous items will ask for the items only since we have enough feed items info
        injectBatchItems(["3", "4"])
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation3], timeout: 5)

        // Loading previous items will ask for the feed item infos since we have not enough feed items
        // and the items since they are not in the db
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = [
                .with { $0.octoObjectID = "6" },
                .with { $0.octoObjectID = "7" }
            ]
            // no cursor, hence no more data to load
        })
        injectBatchItems(["5", "6"])
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation4], timeout: 5)

        injectBatchItems(["7"])
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation5], timeout: 5)
        let hasMoreData = feed.hasMoreData
        XCTAssertEqual(hasMoreData, false)
    }

    func testWhenItemsAreAlreadyInDb() async throws {
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "4", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "5", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2", "3"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)

        await feed.populateWithLocalData(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
    }

    @MainActor
    func testLoadPreviousCallsInitialize() async throws {
        let expectation1 = XCTestExpectation(description: "Items empty")
        let expectation2 = XCTestExpectation(description: "Items uuids are ['1', '2']")
        let expectation3 = XCTestExpectation(description: "Items uuids are ['1', '2', '3', '4']")
        let feed = Feed(id: "1", feedManager: postFeedManager)

        await feed.populateWithLocalData(pageSize: 2)

        feed.$items
            .sink { items in
                guard let items else { return }
                if items.isEmpty {
                    expectation1.fulfill()
                } else if items.map(\.uuid) == ["1", "2"] {
                    expectation2.fulfill()
                } else if items.map(\.uuid) == ["1", "2", "3", "4"] {
                    expectation3.fulfill()
                }
            }.store(in: &storage)
        await fulfillment(of: [expectation1], timeout: 5)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = [
                .with { $0.octoObjectID = "1" },
                .with { $0.octoObjectID = "2" },
                .with { $0.octoObjectID = "3" },
                .with { $0.octoObjectID = "4" },
                .with { $0.octoObjectID = "5" },
            ]
            $0.nextPageCursor = "page2"
        })

        injectBatchItems(["1", "2"])

        // Normally, we should call reset, but ensure that everything is working if we skip the reset
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation2], timeout: 5)

        // Loading previous items will ask for the items only since we have enough feed items info
        injectBatchItems(["3", "4"])
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation3], timeout: 5)
    }

    func testNoInternetAndItemsAreAlreadyInDb() async throws {
        networkMonitor.connectionAvailable = false
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "4", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "5", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2", "3"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        // The stored items are listed, and the caller learns that the server could not be reached
        do {
            try await feed.loadPreviousItems(pageSize: 2)
            XCTFail("The missing network should be reported")
        } catch {
            guard case .noNetwork = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3"] }

        // put back normal value
        networkMonitor.connectionAvailable = true
    }

    func testNoMoreItemsWhenLocal() async throws {
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
        try await assertWithTimeout { await feed.hasMoreData == false }
    }

    // test that if local items are not fully here, we consider that there is no more local data
    func testNoMoreLocalItemsWhenPageIsNotFull() async throws {
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "3"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1"] }
        try await assertWithTimeout { await feed.hasMoreData == false }
    }

    func testNoMoreItemsDuringRefresh() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        // initial refresh will ask for the feed item infos and the items since they are not in the db
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = [
                .with { $0.octoObjectID = "1" },
                .with { $0.octoObjectID = "2" },
            ]
            $0.nextPageCursor = ""
        })
        injectBatchItems(["1", "2"])

        try await feed.refresh(pageSize: 2)

        let hasMoreData = await feed.hasMoreData
        XCTAssertEqual(hasMoreData, false)
    }

    func testNoMoreItemsDuringLoadPrevious() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        // initial refresh will ask for the feed item infos and the items since they are not in the db
        injectFeedItemInfos(["1", "2", "3"], nextPageCursor: nil)
        injectBatchItems(["1", "2"])

        try await feed.refresh(pageSize: 2)

        var hasMoreData = await feed.hasMoreData
        XCTAssertEqual(hasMoreData, true)

        injectBatchItems(["3"])
        try await feed.loadPreviousItems(pageSize: 2)

        hasMoreData = await feed.hasMoreData
        XCTAssertEqual(hasMoreData, false)
    }

    func testTheEndOfTheStoredItemsIsNotTheServerEnd() async throws {
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")
        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2"]))

        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)

        let hasMoreData = await feed.hasMoreData
        let hasReachedServerEnd = await feed.hasReachedServerEnd
        XCTAssertFalse(hasMoreData)
        XCTAssertFalse(hasReachedServerEnd)
    }

    func testTheServerEndIsReachedOnceTheLastPageIsListed() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        injectFeedItemInfos(["1", "2", "3"], nextPageCursor: nil)
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)

        var hasReachedServerEnd = await feed.hasReachedServerEnd
        XCTAssertFalse(hasReachedServerEnd)

        injectBatchItems(["3"])
        try await feed.loadPreviousItems(pageSize: 2)

        hasReachedServerEnd = await feed.hasReachedServerEnd
        XCTAssertTrue(hasReachedServerEnd)
    }

    func testAFeedListingItsStoredItemsAgainNoLongerKnowsTheServerEnd() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        injectFeedItemInfos(["1", "2"], nextPageCursor: nil)
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        var hasReachedServerEnd = await feed.hasReachedServerEnd
        XCTAssertTrue(hasReachedServerEnd)

        // A screen opening again on the same feed lists what is stored first: the server may have more by now.
        await feed.populateWithLocalData(pageSize: 2)
        hasReachedServerEnd = await feed.hasReachedServerEnd
        XCTAssertFalse(hasReachedServerEnd)
    }

    func testAFeedEndsOnItsStoredItemsUntilARefreshSucceeds() async throws {
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")
        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2"]))

        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)
        var endsOnStoredItems = await feed.endsOnStoredItems
        XCTAssertTrue(endsOnStoredItems)

        // A failed refresh tells nothing about where the server's feed ends.
        networkMonitor.connectionAvailable = false
        do {
            try await feed.refresh(pageSize: 2)
            XCTFail("The missing network should be reported")
        } catch {
            guard case .noNetwork = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
        networkMonitor.connectionAvailable = true
        endsOnStoredItems = await feed.endsOnStoredItems
        XCTAssertTrue(endsOnStoredItems)

        // The two stored items are up to date: only the feed's first page is asked for.
        injectFeedItemInfos(["1", "2", "3"], nextPageCursor: nil)
        try await feed.refresh(pageSize: 2)
        endsOnStoredItems = await feed.endsOnStoredItems
        XCTAssertFalse(endsOnStoredItems)
    }

    func testAFeedWithStoredItemsLeftToPageDoesNotEndOnThem() async throws {
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")
        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2", "3"]))

        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)

        // The next page is still to load: it asks the server, which tells where the feed ends.
        let endsOnStoredItems = await feed.endsOnStoredItems
        XCTAssertFalse(endsOnStoredItems)
    }

    func testItemsNotFetchedIfNotNecessary() async throws {
        // Preconditions: populate db with existing posts
        let refDate = Date()
        // be sure to have feedItemInfos in db to avoid items being cleaned
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "0", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "9", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")
        let posts = [
            createPost(id: "0", updateDate: refDate - 1),
            createPost(id: "1", updateDate: refDate),
            createPost(id: "2", updateDate: refDate + 1),
            createPost(id: "9", updateDate: refDate),
        ]
        try await postsDatabase.upsert(posts: posts)

        // Create request
        let feedItemInfos = [
            FeedItemInfo(feedId: "x", itemId: "0", updateDate: refDate, featuredChildId: nil),
            FeedItemInfo(feedId: "x", itemId: "1", updateDate: refDate, featuredChildId: nil),
            FeedItemInfo(feedId: "x", itemId: "2", updateDate: refDate, featuredChildId: nil),
            FeedItemInfo(feedId: "x", itemId: "3", updateDate: refDate, featuredChildId: nil),
        ]

        let missingPosts = try await postsDatabase.getMissingPosts(infos: feedItemInfos)

        // Expecting 0 because feedItemInfo says there is a more recent version and 3 because we don't have it in db
        XCTAssertEqual(missingPosts.sorted(), ["0", "3"])
    }

    func testBlockedUserContentIsFilteredOut() async throws {
        // put some data in the db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "4", updateDate: Date(), featuredChildId: nil),
                FeedItemInfo(feedId: "1", itemId: "5", updateDate: Date(), featuredChildId: nil),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: [
            createPost(id: "1", authorId: "user1"),
            createPost(id: "2", authorId: "user2"),
            createPost(id: "3", authorId: "user3"),
            createPost(id: "4", authorId: "user2"),
            createPost(id: "5", authorId: "user4"),
        ])

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)

        await feed.populateWithLocalData(pageSize: 10)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4", "5"] }

        blockedUserIdsProvider.mockBlockedUserIds(["user2", "user4"])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "3"] }
    }

    /// The last reference to a feed can go away off the main thread while a value of its items is still queued on
    /// the main queue: the value then reaches a feed being released, and must leave it alone.
    func testAFeedReleasedOffTheMainThreadIgnoresTheItemsQueuedOnTheMainQueue() async throws {
        try await insert(feedItems: ["1"], feedId: "1", db: feedsDatabase)
        try await postsDatabase.upsert(posts: [createPost(id: "1", authorId: "user1")])
        let blockedUserIdsProvider = blockedUserIdsProvider!
        let holder = FeedHolder(feed: FeedReleasedOffTheMainThread(id: "1", feedManager: postFeedManager) {
            // the items publisher delivers on the main queue: this queues a value there
            blockedUserIdsProvider.mockBlockedUserIds(["user1"])
        })
        await holder.feed?.populateWithLocalData(pageSize: 10)
        try await assertWithTimeout { await holder.feed?.items?.map(\.uuid) == ["1"] }
        // runs what is still queued on the main queue, so that nothing holds the feed when it is released
        await MainActor.run { }

        weak let releasedFeed = holder.feed
        await Task.detached { holder.feed = nil }.value

        XCTAssertNil(releasedFeed)
    }

    @MainActor
    func testFetchAll() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        // initial refresh will ask for the feed item infos and the items since they are not in the db
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = (1..<98).map { identifier in
                Com_Octopuscommunity_FeedItemInfo.with { $0.octoObjectID = "\(identifier)" }
           }
            $0.nextPageCursor = ""
        })
        injectBatchItems((1..<98).map { "\($0)" })

        var publishedItems: [Post]?
        var updateCount = 0
        feed.$items.sink { items in
            publishedItems = items
            updateCount += 1
        }.store(in: &storage)

        try await feed.fetchAll()

        let hasMoreData = feed.hasMoreData
        let items = feed.items
        XCTAssertEqual(hasMoreData, false)
        XCTAssertEqual(items?.map { $0.uuid }, (1..<98).map { "\($0)" })
        XCTAssertEqual(publishedItems, items)
        XCTAssertEqual(updateCount, 2)
    }

    @MainActor
    func testFetchAllWhenFeedHasBeenInitialized() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        // initial refresh will ask for the feed item infos and the items since they are not in the db
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = (1...50).map { identifier in
                Com_Octopuscommunity_FeedItemInfo.with { $0.octoObjectID = "\(identifier)" }
           }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems((1...25).map { "\($0)" })

        try await feed.refresh(pageSize: 25)

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = (51...80).map { identifier in
                Com_Octopuscommunity_FeedItemInfo.with { $0.octoObjectID = "\(identifier)" }
           }
            $0.nextPageCursor = "page3"
        })
        injectBatchItems((26...80).map { "\($0)" })

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = (81...123).map { identifier in
                Com_Octopuscommunity_FeedItemInfo.with { $0.octoObjectID = "\(identifier)" }
           }
            $0.nextPageCursor = ""
        })
        injectBatchItems((81...123).map { "\($0)" })

        var publishedItems: [Post]?
        var updateCount = 0
        feed.$items.sink { items in
            publishedItems = items
            updateCount += 1
        }.store(in: &storage)

        try await feed.fetchAll()

        let hasMoreData = feed.hasMoreData
        let items = feed.items
        XCTAssertEqual(hasMoreData, false)
        XCTAssertEqual(items?.map { $0.uuid }, (1...123).map { "\($0)" })
        XCTAssertEqual(publishedItems, items)
        XCTAssertEqual(updateCount, 2)
    }

    @MainActor
    func testFetchAllWhenAllWasLoaded() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        // initial refresh will ask for the feed item infos and the items since they are not in the db
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = (1..<72).map { identifier in
                Com_Octopuscommunity_FeedItemInfo.with { $0.octoObjectID = "\(identifier)" }
           }
            $0.nextPageCursor = ""
        })
        injectBatchItems((1..<72).map { "\($0)" })

        try await feed.refresh(pageSize: 72)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = (1..<73).map { identifier in
                Com_Octopuscommunity_FeedItemInfo.with { $0.octoObjectID = "\(identifier)" }
           }
            $0.nextPageCursor = ""
        })
        injectBatchItems(["72"])

        var publishedItems: [Post]?
        var updateCount = 0
        feed.$items.sink { items in
            publishedItems = items
            updateCount += 1
        }.store(in: &storage)

        try await feed.fetchAll()

        let hasMoreData = feed.hasMoreData
        let items = feed.items
        XCTAssertEqual(hasMoreData, false)
        XCTAssertEqual(items?.map { $0.uuid }, (1..<73).map { "\($0)" })
        XCTAssertEqual(publishedItems, items)
        XCTAssertEqual(updateCount, 2)
    }

    func testWithFeaturedComment() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        // initial refresh will ask for the feed item infos and the items since they are not in the db
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = [
                .with {
                    $0.octoObjectID = "1"
                    $0.octoObjectUpdatedAt = 1
                    $0.highlightedChildID = "child_1"
                },
                .with { $0.octoObjectID = "2" },
            ]
            $0.nextPageCursor = "page2"
        })

        mockOctoService.injectNextGetBatchResponse(.with {
            $0.responses = [
                .with {
                    $0.octoObjectID = "1"
                    $0.octoObject = Com_Octopuscommunity_OctoObject.with {
                        $0.createdAt = 0
                        $0.id = "1"
                        $0.parentID = ""
                        $0.createdBy = .with {
                            $0.profileID = "authorId"
                            $0.nickname = "me"
                        }
                        $0.content = .with {
                            $0.post = .with {
                                $0.text = "title"
                            }
                        }
                    }
                },
                .with {
                    $0.octoObjectID = "2"
                    $0.octoObject = Com_Octopuscommunity_OctoObject.with {
                        $0.createdAt = 0
                        $0.id = "2"
                        $0.parentID = ""
                        $0.createdBy = .with {
                            $0.profileID = "authorId"
                            $0.nickname = "me"
                        }
                        $0.content = .with {
                            $0.post = .with {
                                $0.text = "title"
                            }
                        }
                    }
                },
                .with {
                    $0.octoObjectID = "child_1"
                    $0.octoObject = Com_Octopuscommunity_OctoObject.with {
                        $0.createdAt = 0
                        $0.id = "child_1"
                        $0.parentID = ""
                        $0.createdBy = .with {
                            $0.profileID = "authorId"
                            $0.nickname = "me"
                        }
                        $0.content = .with {
                            $0.comment = .with {
                                $0.text = "comment"
                            }
                        }
                    }
                }
            ]
        })

        try await feed.refresh(pageSize: 2)

        var hasMoreData = await feed.hasMoreData
        var items = await feed.items
        XCTAssertEqual(hasMoreData, true)
        XCTAssertNotNil(items?[0].featuredComment)
        XCTAssertNil(items?[1].featuredComment)

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = [
                .with {
                    $0.octoObjectID = "3"
                    $0.octoObjectUpdatedAt = 1
                    $0.highlightedChildID = "child_3"
                },
                .with { $0.octoObjectID = "3" },
            ]
        })
        mockOctoService.injectNextGetBatchResponse(.with {
            $0.responses = [
                .with {
                    $0.octoObjectID = "3"
                    $0.octoObject = Com_Octopuscommunity_OctoObject.with {
                        $0.createdAt = 0
                        $0.id = "3"
                        $0.parentID = ""
                        $0.createdBy = .with {
                            $0.profileID = "authorId"
                            $0.nickname = "me"
                        }
                        $0.content = .with {
                            $0.post = .with {
                                $0.text = "title"
                            }
                        }
                    }
                },
                .with {
                    $0.octoObjectID = "child_3"
                    $0.octoObject = Com_Octopuscommunity_OctoObject.with {
                        $0.createdAt = 0
                        $0.id = "child_3"
                        $0.parentID = ""
                        $0.createdBy = .with {
                            $0.profileID = "authorId"
                            $0.nickname = "me"
                        }
                        $0.content = .with {
                            $0.comment = .with {
                                $0.text = "comment"
                            }
                        }
                    }
                }
            ]
        })
        try await feed.loadPreviousItems(pageSize: 2)

        hasMoreData = await feed.hasMoreData
        items = await feed.items
        XCTAssertEqual(hasMoreData, false)
        XCTAssertNotNil(items?[0].featuredComment)
        XCTAssertNil(items?[1].featuredComment)
        XCTAssertNotNil(items?[2].featuredComment)
    }

    func testClean() async throws {
        // precondition: fill the db with data that will be cleaned

        // use a custom env, because we need the db before initializing the FeedManager
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .blockedUserIdsProvider)

        postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        feedsDatabase = injector.getInjected(identifiedBy: Injected.feedItemInfosDatabase)

        try await insert(feedItems: ["1", "2", "3"], feedId: "1", db: feedsDatabase)
        try await insert(feedItems: ["1", "2", "4", "10"], feedId: "2", db: feedsDatabase)

        let createdPosts = [
            createPost(id: "0"),
            createPost(id: "1"),
            createPost(id: "2"),
            createPost(id: "3"),
            createPost(id: "4"),
            createPost(id: "5"),
            createPost(id: "6"),
        ]
        try await postsDatabase.upsert(posts: createdPosts)

        // check that after FeedManager init, Feed Items db is cleaned
        postFeedManager = PostsFeedManager.factory(injector: injector)

        let postsDatabase = self.postsDatabase!
        try await assertWithTimeout {
            Set(try await postsDatabase.getPosts(ids: createdPosts.map { $0.uuid }).map(\.uuid)) == ["1", "2", "3", "4"]
        }
    }

    private func injectFeedItemInfos(_ itemInfos: [String], nextPageCursor: String?) {
        let itemInfos = itemInfos.map { itemInfo in
            Com_Octopuscommunity_FeedItemInfo.with {
                $0.octoObjectID = itemInfo
            }
        }
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = itemInfos
            if let nextPageCursor {
                $0.nextPageCursor = nextPageCursor
            }
        })
    }

    func testFetchAllUntilAnItemAlreadyListedLocallyStillReachesTheServer() async throws {
        // Preconditions: the target is in the local first page, but the server has a newer item
        try await feedsDatabase.upsert(
            feedItemInfos: ["1", "2"].map {
                FeedItemInfo(feedId: "1", itemId: $0, updateDate: Date(), featuredChildId: nil)
            },
            feedId: "1")
        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2"]))

        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 10)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2", "3"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["3"])

        try await feed.fetchAll(until: "1")

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3"] }
    }

    func testFetchAllUntilAnItemOnlyOnTheServerLoadsUntilIt() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 10)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2", "3"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["1", "2", "3"])

        try await feed.fetchAll(until: "3")

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3"] }
    }

    func testRefreshLargerThanAServerPageFillsFromTheNextPages() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 10)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["3", "4"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["1", "2", "3", "4"])

        try await feed.refresh(pageSize: 4)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4"] }
        let hasMoreData = await feed.hasMoreData
        XCTAssertFalse(hasMoreData)
    }

    func testRefreshStopsFillingOnAnEmptyServerPage() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 10)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        // An empty page that still hands back a cursor must not be followed forever
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.nextPageCursor = "page3"
        })
        injectBatchItems(["1", "2"])

        try await feed.refresh(pageSize: 4)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
    }

    /// The feed changed between two server pages: the second one lists again an item of the first one.
    func testANextPageListingAgainAnItemOfThePreviousOneKeepsEveryItemOnceInPlace() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2", "3"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["2", "4", "5"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["3", "4"])
        try await feed.loadPreviousItems(pageSize: 2)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4"] }
    }

    func testAFailedNextPageKeepsTheFeedOpenWhenTheServerHasMorePages() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        // No next page injected: fetching it fails
        do {
            try await feed.loadPreviousItems(pageSize: 2)
            XCTFail("The failed page should be reported")
        } catch { }

        let hasMoreData = await feed.hasMoreData
        XCTAssertTrue(hasMoreData)

        // The next load asks the server for the page again
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["3", "4"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["3", "4"])
        try await feed.loadPreviousItems(pageSize: 2)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4"] }
    }

    /// The items of a feed that fits in one server page are fetched page after page: one failing must not end it.
    func testAFailedNextPageKeepsOpenAFeedThatFitsInOneServerPage() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2", "3", "4"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        // No batch response injected: fetching the items 3 and 4 fails
        do {
            try await feed.loadPreviousItems(pageSize: 2)
            XCTFail("The failed page should be reported")
        } catch { }

        let hasMoreData = await feed.hasMoreData
        XCTAssertTrue(hasMoreData)
    }

    /// `fetchAll(until:)` asks for the pages until the item: a page failing must end it instead of asking for the page
    /// again and again.
    func testFetchAllUntilAnItemEndsWhenANextPageFails() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        // No next page injected: fetching it fails
        do {
            try await feed.fetchAll(until: "3")
            XCTFail("The failed page should be reported")
        } catch { }
    }

    func testANextPageListingAnItemTwiceListsItOnce() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["3", "4", "3", "5"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["3", "4", "5"])
        try await feed.loadPreviousItems(pageSize: 3)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4", "5"] }
    }

    /// A page stored by a call that failed on its items keeps the feed on its cursor: once the stored page is listed,
    /// the page asked for again only lists stored items, and the one after it is asked for in the same call.
    func testAPageListingOnlyStoredItemsAsksForTheNextOne() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["3", "4"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page3"
        })
        // No batch response injected: the page is stored, fetching its items fails
        do {
            try await feed.loadPreviousItems(pageSize: 2)
            XCTFail("The failed page should be reported")
        } catch { }

        injectBatchItems(["3", "4"])
        try await feed.loadPreviousItems(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4"] }

        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["3", "4"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page3"
        })
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["5", "6"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["5", "6"])
        try await feed.loadPreviousItems(pageSize: 2)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4", "5", "6"] }
        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["page2", "page2", "page3"])

        // The feed is listed to its end: fetching it all asks again for the last page asked for, not the first one
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["5", "6", "7"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["7"])
        try await feed.fetchAll()

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4", "5", "6", "7"] }
        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["page2", "page2", "page3", "page3"])
    }

    func testAnEmptyNextPageEndsTheLoad() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        // An empty page that still hands back a cursor must not be followed in the same load
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.nextPageCursor = "page3"
        })
        try await feed.loadPreviousItems(pageSize: 2)

        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["page2"])
        let hasMoreData = await feed.hasMoreData
        XCTAssertTrue(hasMoreData)
    }

    func testPagesListingOnlyStoredItemsAreAskedForUpToALimitInOneCall() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        for cursor in ["page3", "page4", "page5"] {
            mockFeedService.injectNextGetNextFeedPage(.with {
                $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
                $0.nextPageCursor = cursor
            })
        }
        try await feed.loadPreviousItems(pageSize: 2)

        XCTAssertEqual(mockFeedService.getNextFeedPageCursors, ["page2", "page3", "page4"])
        let hasMoreData = await feed.hasMoreData
        XCTAssertTrue(hasMoreData)
        let items = await feed.items?.map(\.uuid)
        XCTAssertEqual(items, ["1", "2"])
    }

    func testARefreshFailingOnALaterPageLeavesTheFeedAsItWas() async throws {
        // Preconditions: the feed was paged in to four items
        try await feedsDatabase.upsert(
            feedItemInfos: ["1", "2", "3", "4"].map {
                FeedItemInfo(feedId: "1", itemId: $0, updateDate: Date(), featuredChildId: nil)
            },
            feedId: "1")
        let feed = Feed(id: "1", feedManager: postFeedManager)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["5", "1"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        // No second page injected: fetching it fails

        do {
            try await feed.refresh(pageSize: 4)
            XCTFail("The refresh should fail on its second page")
        } catch { }

        let feedItemIds = try await feedsDatabase.feedItemInfos(feedId: "1", pageSize: 10, lastPageIdx: 0)
            .map(\.itemId)
        XCTAssertEqual(feedItemIds, ["1", "2", "3", "4"])
    }

    /// A refresh of a window paged deep into a long thread can miss thousands of items: one call per item would be
    /// too many calls, one call for all of them too large a response.
    func testTheItemsMissingFromARefreshAreFetchedAHundredAtATime() async throws {
        let ids = (1...250).map { "\($0)" }
        let feed = Feed(id: "1", feedManager: postFeedManager)
        injectFeedItemInfos(ids, nextPageCursor: nil)
        injectBatchItems(Array(ids[0..<100]))
        injectBatchItems(Array(ids[100..<200]))
        injectBatchItems(Array(ids[200...]))

        try await feed.refresh(pageSize: 250)

        XCTAssertEqual(mockOctoService.getBatchRequestedIds.map(\.count), [100, 100, 50])
        XCTAssertEqual(Set(mockOctoService.getBatchRequestedIds.flatMap { $0 }), Set(ids))
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ids }
    }

    func testTheFeaturedCommentsMissingFromARefreshAreFetchedAfterTheirPosts() async throws {
        let ids = (1...150).map { "\($0)" }
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ids.map { id in
                .with {
                    $0.octoObjectID = id
                    $0.highlightedChildID = "child_\(id)"
                }
            }
        })
        let childIds = ids.map { "child_\($0)" }
        injectBatchItems(Array(ids[0..<100]))
        injectBatchItems(Array(ids[100...]), comments: Array(childIds[0..<50]))
        injectBatchItems([], comments: Array(childIds[50...]))

        try await feed.refresh(pageSize: 150)

        XCTAssertEqual(mockOctoService.getBatchRequestedIds.map(\.count), [100, 100, 100])
        XCTAssertEqual(Set(mockOctoService.getBatchRequestedIds.joined().suffix(150)), Set(childIds))
        try await assertWithTimeout {
            await feed.items?.map { $0.featuredComment?.uuid } == childIds
        }
    }

    /// The calls of a refresh are one read: a session change during one of them sends them all again.
    func testASessionChangeDuringTheItemsCallsSendsThemAllAgain() async throws {
        let ids = (1...150).map { "\($0)" }
        let feed = Feed(id: "1", feedManager: postFeedManager)
        injectFeedItemInfos(ids, nextPageCursor: nil)
        injectBatchItems(Array(ids[0..<100]))
        mockOctoService.injectNextGetBatchError(.unknown(RefreshingTokenError.userIdNotMatching))
        injectBatchItems(Array(ids[0..<100]))
        injectBatchItems(Array(ids[100...]))

        try await feed.refresh(pageSize: 150)

        XCTAssertEqual(mockOctoService.getBatchRequestedIds.map(\.count), [100, 50, 100, 50])
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ids }
    }

    func testARefreshWhoseSecondItemsCallFailsStoresNoneOfTheItems() async throws {
        // Preconditions: the feed lists one item
        try await feedsDatabase.upsert(
            feedItemInfos: [FeedItemInfo(feedId: "1", itemId: "0", updateDate: Date(), featuredChildId: nil)],
            feedId: "1")
        let ids = (1...150).map { "\($0)" }
        let feed = Feed(id: "1", feedManager: postFeedManager)
        injectFeedItemInfos(ids, nextPageCursor: nil)
        injectBatchItems(Array(ids[0..<100]))
        mockOctoService.injectNextGetBatchError(.unknown(MockError("The second items call fails")))

        do {
            try await feed.refresh(pageSize: 150)
            XCTFail("The refresh should fail on its second items call")
        } catch { }

        XCTAssertEqual(mockOctoService.getBatchRequestedIds.count, 2)
        let storedPosts = try await postsDatabase.getPosts(ids: ids)
        XCTAssertTrue(storedPosts.isEmpty)
        let feedItemIds = try await feedsDatabase.feedItemInfos(feedId: "1", pageSize: 10, lastPageIdx: 0)
            .map(\.itemId)
        XCTAssertEqual(feedItemIds, ["0"])
    }

    func testRefreshingTheNewestItemsKeepsTheOlderOnesInOneServerCall() async throws {
        // Preconditions: the feed lists four items and has older ones on the server
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2", "3", "4"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2", "3", "4"])
        try await feed.refresh(pageSize: 4)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4"] }

        // A new item came in: the newest server page reaches the stored items. No next page is injected, so
        // fetching it would fail the refresh.
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["5", "1"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["5"])
        try await feed.refreshNewestItems(pageSize: 5)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["5", "1", "2", "3", "4"] }
        let hasMoreData = await feed.hasMoreData
        XCTAssertTrue(hasMoreData)
    }

    func testRefreshingTheNewestItemsOfAFeedPagedToItsEndKeepsEveryItemListed() async throws {
        // Preconditions: the feed lists all its items, it has no more data
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
        let hadMoreData = await feed.hasMoreData
        XCTAssertFalse(hadMoreData)

        // A new item comes in above the listed ones: none of them is pushed out of the list, and the feed still ends
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["5", "1"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["5"])
        try await feed.refreshNewestItems(pageSize: 2)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["5", "1", "2"] }
        let hasMoreData = await feed.hasMoreData
        XCTAssertFalse(hasMoreData)
    }

    func testPollingTheNewestItemsDoesNotDropTheOldestListedOnes() async throws {
        // Preconditions: a thread listing its four newest items out of six, as a member paged in, older ones stored
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2", "3", "4", "5", "6"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2", "3", "4", "5", "6"])
        try await feed.refresh(pageSize: 4)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2", "3", "4"] }

        // Two new items come in while the member reads the oldest listed ones: polling with the listed size keeps
        // them all, the new ones above
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["8", "7", "1"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["8", "7"])
        try await feed.refreshNewestItems(pageSize: 4)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["8", "7", "1", "2", "3", "4"] }
        let hasMoreData = await feed.hasMoreData
        XCTAssertTrue(hasMoreData)
    }

    func testRefreshingTheNewestItemsFallsBackToAFullRefreshWhenTheyDoNotReachTheStoredOnes() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "page2"
        })
        injectBatchItems(["1", "2"])
        try await feed.refresh(pageSize: 2)
        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }

        // More items came in than the newest page holds: the next pages are fetched to know the order again
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["4", "3"].map { id in .with { $0.octoObjectID = id } }
            $0.nextPageCursor = "next"
        })
        mockFeedService.injectNextGetNextFeedPage(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["4", "3"])
        try await feed.refreshNewestItems(pageSize: 4)

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["4", "3", "1", "2"] }
    }

    func testMergingTheNewestPage() {
        func infos(_ ids: [String]) -> [FeedItemInfo] {
            ids.map { FeedItemInfo(feedId: "1", itemId: $0, updateDate: Date(), featuredChildId: nil) }
        }
        let merge = FeedManager<Post, Comment>.mergingNewestPage
        XCTAssertEqual(merge(infos(["5", "2"]), infos(["1", "2", "3"]))?.map(\.itemId), ["5", "2", "3"])
        XCTAssertNil(merge(infos(["5", "4"]), infos(["1", "2", "3"])))
        XCTAssertNil(merge(infos([]), infos(["1"])))
        XCTAssertNil(merge(infos(["1"]), infos([])))
    }

    func testListingSizeKeepsTheItemsListedBeforeTheRefresh() {
        func infos(_ ids: [String]) -> [FeedItemInfo] {
            ids.map { FeedItemInfo(feedId: "1", itemId: $0, updateDate: Date(), featuredChildId: nil) }
        }
        let size = FeedManager<Post, Comment>.listingSize
        // two new items above the three listed
        XCTAssertEqual(size(infos(["5", "4", "1", "2", "3", "0"]), infos(["1", "2", "3"])[...], 3), 5)
        // never below the size asked
        XCTAssertEqual(size(infos(["5", "1", "2", "3"]), infos(["1"])[...], 3), 3)
        // the oldest listed item gone: kept up to the oldest listed one still there
        XCTAssertEqual(size(infos(["5", "4", "1", "2"]), infos(["1", "2", "3"])[...], 3), 4)
        // none of the listed items left
        XCTAssertEqual(size(infos(["5", "4"]), infos(["1"])[...], 3), 3)
    }

    func testRefreshWhenIdleWaitsForTheFetchInProgress() async throws {
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 10)

        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["1"])
        mockFeedService.injectNextInitializeFeed(.with {
            $0.items = ["1", "2"].map { id in .with { $0.octoObjectID = id } }
        })
        injectBatchItems(["2"])

        // The first refresh is in progress when the second one is asked: it must run once the first one ended
        // instead of being ignored. The main actor runs its jobs in order, so the first one has started, and
        // suspended on its server call, once the empty job queued after it ran.
        let firstRefresh = Task { @MainActor in try await feed.refresh(pageSize: 10) }
        await MainActor.run {}
        try await feed.refreshWhenIdle(pageSize: 10)
        try await firstRefresh.value

        try await assertWithTimeout { await feed.items?.map(\.uuid) == ["1", "2"] }
    }

    /// Injects the response of a batch call holding the posts `items`, then the comments `comments`.
    private func injectBatchItems(_ items: [String], comments: [String] = []) {
        let comments = comments.map { itemId in
            Com_Octopuscommunity_OctoObject.with {
                $0.createdAt = 0
                $0.id = itemId
                $0.parentID = ""
                $0.createdBy = .with {
                    $0.profileID = "authorId"
                    $0.nickname = "me"
                }
                $0.content = .with {
                    $0.comment = .with {
                        $0.text = "comment\(itemId)"
                    }
                }
            }
        }
        let posts = items.map { itemId in
            Com_Octopuscommunity_OctoObject.with {
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
        mockOctoService.injectNextGetBatchResponse(.with {
            $0.responses = (posts + comments).map { object in
                .with {
                    $0.octoObjectID = object.id
                    $0.octoObject = object
                }
            }
        })
    }

    private func createPosts(ids: [String]) -> [StorablePost] {
        return ids.map {
            createPost(id: $0, updateDate: Date())
        }
    }

    private func createPost(id: String, updateDate: Date = Date(), authorId: String = "authorId") -> StorablePost {
        StorablePost(uuid: id, text: .init(originalText: "title\(id)", originalLanguage: nil, translatedText: nil),
                     medias: [], poll: nil,
                     author: MinimalProfile(uuid: authorId, nickname: "me", avatarUrl: nil, gamificationLevel: nil),
                     creationDate: Date(),
                     updateDate: updateDate,
                     status: .published, statusReasons: [],
                     parentId: "",
                     descCommentFeedId: "", ascCommentFeedId: "",
                     bridgeClientObjectId: nil, bridgeCatchPhrase: nil, bridgeCtaText: nil,
                     customActionText: nil, customActionTargetLink: nil,
                     aggregatedInfo: .empty, userInteractions: .empty)
    }

    private func insert(feedItems: [String], feedId: String, db: FeedItemInfosDatabase) async throws {
        try await feedsDatabase.upsert(
            feedItemInfos: feedItems.map { FeedItemInfo(feedId: feedId, itemId: $0, updateDate: Date(), featuredChildId: nil) },
            feedId: feedId)
    }
}

/// Holds the only reference to a feed, so that another task can release it.
private final class FeedHolder: @unchecked Sendable {
    var feed: Feed<Post, Comment>?

    init(feed: Feed<Post, Comment>) {
        self.feed = feed
    }
}

/// A feed that, once released, calls `onRelease` then lets the main queue run what is queued on it before its
/// subscriptions are cancelled, as the main thread can do on its own while a feed is released on another thread.
/// What `onRelease` queues on the main queue then reaches a feed that is already being released.
private final class FeedReleasedOffTheMainThread: Feed<Post, Comment> {
    nonisolated(unsafe) private let onRelease: () -> Void

    nonisolated init(id: String, feedManager: FeedManager<Post, Comment>, onRelease: @escaping () -> Void) {
        self.onRelease = onRelease
        super.init(id: id, feedManager: feedManager)
    }

    deinit {
        guard !Thread.isMainThread else { return XCTFail("The feed must be released off the main thread") }
        onRelease()
        DispatchQueue.main.sync { }
    }
}
