//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusRemoteClient
import OctopusGrpcModels
import OctopusDependencyInjection
import SwiftProtobuf
@testable import OctopusCore

class FeedTests: XCTestCase {

    private var mockOctoService: MockOctoService!
    private var mockFeedService: MockFeedService!
    private var postsDatabase: PostsDatabase!
    private var feedsDatabase: FeedItemInfosDatabase!
    private var postFeedManager: FeedManager<Post>!
    private var networkMonitor: MockNetworkMonitor!
    private var blockedUserIdsProvider: MockBlockedUserIdsProvider!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
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
        await fulfillment(of: [expectation1], timeout: 0.5)

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

        await fulfillment(of: [expectation2], timeout: 0.5)

        // Loading previous items will ask for the items only since we have enough feed items info
        injectBatchItems(["3", "4"])
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation3], timeout: 0.5)

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

        await fulfillment(of: [expectation4], timeout: 0.5)

        injectBatchItems(["7"])
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation5], timeout: 0.5)
        let hasMoreData = feed.hasMoreData
        XCTAssertEqual(hasMoreData, false)
    }

    func testWhenItemsAreAlreadyInDb() async throws {
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "4", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "5", updateDate: Date()),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2", "3"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)

        await feed.populateWithLocalData(pageSize: 2)
        try await delay()

        let feedItems = await feed.items
        XCTAssertEqual(feedItems?.map { $0.uuid }, ["1", "2"])
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
        await fulfillment(of: [expectation1], timeout: 0.5)

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

        await fulfillment(of: [expectation2], timeout: 0.5)

        // Loading previous items will ask for the items only since we have enough feed items info
        injectBatchItems(["3", "4"])
        try await feed.loadPreviousItems(pageSize: 2)

        await fulfillment(of: [expectation3], timeout: 0.5)
    }

    func testNoInternetAndItemsAreAlreadyInDb() async throws {
        networkMonitor.connectionAvailable = false
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "4", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "5", updateDate: Date()),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2", "3"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)
        try await delay()

        var feedItems = await feed.items
        XCTAssertEqual(feedItems?.map { $0.uuid }, ["1", "2"])

        try await feed.loadPreviousItems(pageSize: 2)
        feedItems = await feed.items
        XCTAssertEqual(feedItems?.map { $0.uuid }, ["1", "2", "3"])

        // put back normal value
        networkMonitor.connectionAvailable = true
    }

    func testNoMoreItemsWhenLocal() async throws {
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date()),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "2"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)
        try await delay()

        let feedItems = await feed.items
        let hasMoreData = await feed.hasMoreData
        XCTAssertEqual(feedItems?.map { $0.uuid }, ["1", "2"])
        XCTAssertEqual(hasMoreData, false)
    }

    // test that if local items are not fully here, we consider that there is no more local data
    func testNoMoreLocalItemsWhenPageIsNotFull() async throws {
        // Preconditions: some items and items infos are already in db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date()),
            ],
            feedId: "1")

        try await postsDatabase.upsert(posts: createPosts(ids: ["1", "3"]))

        // when created, the feed should have the first page
        let feed = Feed(id: "1", feedManager: postFeedManager)
        await feed.populateWithLocalData(pageSize: 2)
        try await delay()

        let feedItems = await feed.items
        let hasMoreData = await feed.hasMoreData
        XCTAssertEqual(feedItems?.map { $0.uuid }, ["1"])
        XCTAssertEqual(hasMoreData, false)
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

    func testItemsNotFetchedIfNotNecessary() async throws {
        // Preconditions: populate db with existing posts
        let refDate = Date()
        // be sure to have feedItemInfos in db to avoid items being cleaned
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "0", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "9", updateDate: Date()),
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
            FeedItemInfo(feedId: "x", itemId: "0", updateDate: refDate),
            FeedItemInfo(feedId: "x", itemId: "1", updateDate: refDate),
            FeedItemInfo(feedId: "x", itemId: "2", updateDate: refDate),
            FeedItemInfo(feedId: "x", itemId: "3", updateDate: refDate),
        ]

        let missingPosts = try await postsDatabase.getMissingPosts(infos: feedItemInfos)

        // Expecting 0 because feedItemInfo says there is a more recent version and 3 because we don't have it in db
        XCTAssertEqual(missingPosts.sorted(), ["0", "3"])
    }

    func testBlockedUserContentIsFilteredOut() async throws {
        // put some data in the db
        try await feedsDatabase.upsert(
            feedItemInfos: [
                FeedItemInfo(feedId: "1", itemId: "1", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "2", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "3", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "4", updateDate: Date()),
                FeedItemInfo(feedId: "1", itemId: "5", updateDate: Date()),
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
        try await delay()

        let postsBeforeBlockingUsers = await feed.items
        XCTAssertEqual(postsBeforeBlockingUsers?.map(\.uuid), ["1", "2", "3", "4", "5"])

        blockedUserIdsProvider.mockBlockedUserIds(["user2", "user4"])
        try await delay()

        let postsAfterBlockingUsers = await feed.items
        XCTAssertEqual(postsAfterBlockingUsers?.map(\.uuid), ["1", "3"])
    }

    func testClean() async throws {
        // precondition: fill the db with data that will be cleaned

        // use a custom env, because we need the db before initializing the FeedManager
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
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

        try await delay() // needed because clean is async
        let postsInDb = try await postsDatabase.getPosts(ids: createdPosts.map { $0.uuid })
        XCTAssert(Set(postsInDb.map { $0.uuid }) == ["1", "2", "3", "4"])
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

    private func injectBatchItems(_ items: [String]) {
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
            $0.responses = posts.map { post in
                .with {
                    $0.octoObject = post
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
        StorablePost(uuid: id, text: "title\(id)", medias: [], poll: nil,
                     author: MinimalProfile(uuid: authorId, nickname: "me", avatarUrl: nil),
                     creationDate: Date(),
                     updateDate: updateDate,
                     status: .published, statusReasons: [],
                     parentId: "",
                     descCommentFeedId: "", ascCommentFeedId: "", aggregatedInfo: .empty, userInteractions: .empty)
    }

    private func insert(feedItems: [String], feedId: String, db: FeedItemInfosDatabase) async throws {
        try await feedsDatabase.upsert(
            feedItemInfos: feedItems.map { FeedItemInfo(feedId: feedId, itemId: $0, updateDate: Date()) },
            feedId: feedId)
    }
}
