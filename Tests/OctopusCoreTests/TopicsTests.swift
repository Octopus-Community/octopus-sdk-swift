//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

class TopicsTests: XCTestCase {
    /// Object that is tested
    private var topicsRepository: TopicsRepository!

    private var mockOctoService: MockOctoService!
    private var mockUserService: MockUserService!
    private var injector: Injector!
    private var storage = [AnyCancellable]()

    override func setUp() {
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { TopicsDatabase(injector: $0) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        injector.registerMocks(.remoteClient, .networkMonitor, .authProvider, .blockedUserIdsProvider)

        topicsRepository = TopicsRepository(injector: injector)
        mockOctoService = (injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService)
        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient).userService as! MockUserService)
    }

    func testGetLocalAndRemoteTopics() async throws {
        let localExpectation = XCTestExpectation(description: "DB updated")

        topicsRepository.$topics
            .sink { topics in
                if topics.first?.name == "1st Topic" {
                    localExpectation.fulfill()
                }
            }.store(in: &storage)

        injectRemoteItems([
            .init(uuid: "1", name: "1st Topic", description: "Desc", followStatus: .followed, sections: [], feedId: "")
        ])
        try await topicsRepository.fetchTopics()

        await fulfillment(of: [localExpectation], timeout: 5)
    }

    func testTopicsAreInOrder() async throws {
        let localExpectation = XCTestExpectation(description: "DB updated")

        var topics: [Topic] = []
        topicsRepository.$topics
            .sink {
                topics = $0
                if !topics.isEmpty {
                    localExpectation.fulfill()
                }
            }.store(in: &storage)

        injectRemoteItems([
            .init(uuid: "1", name: "1st Topic", description: "", followStatus: .followed, sections: [], feedId: ""),
            .init(uuid: "2", name: "2nd Topic", description: "", followStatus: .followed, sections: [], feedId: ""),
            .init(uuid: "3", name: "3rd Topic", description: "", followStatus: .followed, sections: [], feedId: ""),
            .init(uuid: "0", name: "4th Topic", description: "", followStatus: .followed, sections: [], feedId: ""),
        ])
        try await topicsRepository.fetchTopics()

        await fulfillment(of: [localExpectation], timeout: 5)
        XCTAssertEqual(topics.map { $0.uuid }, ["1", "2", "3", "0"])
    }

    func testSyncFollowTopicsHappyPath() async throws {
        mockUserService.injectNextSyncFollowTopicsResponse(
            .with {
                $0.results = [
                    .with { $0.topicID = "t1"; $0.status = .syncFollowApplied },
                    .with { $0.topicID = "t2"; $0.status = .syncFollowAlreadyFollowed },
                ]
            }
        )
        // fetchTopics is called by the repository after a successful sync — inject an empty
        // response so the refresh doesn't blow up.
        mockOctoService.injectNextGetTopicsResponse(.with { _ in })

        let actions: [SyncFollowTopicAction] = [
            .init(topicId: "t1", followed: true, actionDate: Date(timeIntervalSince1970: 1_700_000_000)),
            .init(topicId: "t2", followed: true, actionDate: Date(timeIntervalSince1970: 1_700_000_001)),
        ]

        let results = try await topicsRepository.syncFollowTopics(actions: actions)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].topicId, "t1")
        XCTAssertEqual(results[0].status, .applied)
        XCTAssertEqual(results[1].topicId, "t2")
        XCTAssertEqual(results[1].status, .alreadyFollowed)
        XCTAssertEqual(mockUserService.syncFollowTopicsCallCount, 1)
    }

    func testSyncFollowTopicsEmptyListSkipsNetworkCall() async throws {
        let results = try await topicsRepository.syncFollowTopics(actions: [])

        XCTAssertEqual(results, [])
        XCTAssertEqual(mockUserService.syncFollowTopicsCallCount, 0)
    }

    func testSyncFollowTopicsNotConnectedThrows() async throws {
        let mockAuthProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
            as! MockAuthenticatedCallProvider
        mockAuthProvider.isConnected = false

        do {
            _ = try await topicsRepository.syncFollowTopics(actions: [
                .init(topicId: "t1", followed: true, actionDate: Date()),
            ])
            XCTFail("Expected throw")
        } catch AuthenticatedActionError.userNotAuthenticated {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(mockUserService.syncFollowTopicsCallCount, 0)
    }

    func testSyncFollowTopicsNoNetworkThrows() async throws {
        let mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
            as! MockNetworkMonitor
        mockNetworkMonitor.connectionAvailable = false

        do {
            _ = try await topicsRepository.syncFollowTopics(actions: [
                .init(topicId: "t1", followed: true, actionDate: Date()),
            ])
            XCTFail("Expected throw")
        } catch AuthenticatedActionError.noNetwork {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(mockUserService.syncFollowTopicsCallCount, 0)
    }

    func testSyncFollowTopicsServerErrorIsThrown() async throws {
        // Intentionally do NOT inject a response — MockUserService.syncFollowTopics then
        // throws `RemoteClientError.unknown(...)`, which the repository must map to
        // `AuthenticatedActionError.serverError(...)`.
        do {
            _ = try await topicsRepository.syncFollowTopics(actions: [
                .init(topicId: "t1", followed: true, actionDate: Date()),
            ])
            XCTFail("Expected throw")
        } catch AuthenticatedActionError.serverError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSyncFollowTopicsStatusMapping() async throws {
        let protoCases: [(Com_Octopuscommunity_SyncFollowTopicStatus, SyncFollowTopicResult.Status)] = [
            (.syncFollowApplied, .applied),
            (.syncFollowSkipped, .skipped),
            (.syncFollowTopicNotFound, .topicNotFound),
            (.syncFollowNotFollowable, .notFollowable),
            (.syncFollowNotUnfollowable, .notUnfollowable),
            (.syncFollowAlreadyFollowed, .alreadyFollowed),
            (.syncFollowAlreadyUnfollowed, .alreadyUnfollowed),
            (.syncFollowError, .unknownError),
            (.syncFollowUnspecified, .unknownError),
        ]

        mockUserService.injectNextSyncFollowTopicsResponse(
            .with {
                $0.results = protoCases.enumerated().map { index, pair in
                    .with {
                        $0.topicID = "t\(index)"
                        $0.status = pair.0
                    }
                }
            }
        )
        mockOctoService.injectNextGetTopicsResponse(.with { _ in })

        let actions = protoCases.indices.map { index in
            SyncFollowTopicAction(topicId: "t\(index)", followed: true, actionDate: Date())
        }
        let results = try await topicsRepository.syncFollowTopics(actions: actions)

        XCTAssertEqual(results.count, protoCases.count)
        for (index, pair) in protoCases.enumerated() {
            XCTAssertEqual(results[index].status, pair.1, "Mismatch at index \(index) (proto: \(pair.0))")
            XCTAssertEqual(results[index].topicId, "t\(index)")
        }
    }

    func testSyncFollowTopicsRefreshesCacheOnSuccess() async throws {
        let initialCount = mockOctoService.getTopicsCallCount

        mockUserService.injectNextSyncFollowTopicsResponse(
            .with { $0.results = [.with { $0.topicID = "t1"; $0.status = .syncFollowApplied }] }
        )
        mockOctoService.injectNextGetTopicsResponse(.with { _ in })

        _ = try await topicsRepository.syncFollowTopics(actions: [
            .init(topicId: "t1", followed: true, actionDate: Date()),
        ])

        XCTAssertEqual(mockOctoService.getTopicsCallCount, initialCount + 1)
    }

    func injectRemoteItems(_ items: [StorableTopic]) {
        let topics = items.map { item in
            Com_Octopuscommunity_OctoObject.with {
                $0.createdAt = Date().timestampMs
                $0.id = item.uuid
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = item.name
                        $0.description_p = item.description
                        $0.followStatus = .topicFollowed
                    }
                }
            }
        }
        mockOctoService.injectNextGetTopicsResponse(.with { $0.topics = topics })
    }
}
