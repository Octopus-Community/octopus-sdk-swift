//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
@testable import OctopusRemoteClient
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

        let topics = Locked<[Topic]>([])
        topicsRepository.$topics
            .sink {
                topics.value = $0
                if !$0.isEmpty {
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
        XCTAssertEqual(topics.value.map { $0.uuid }, ["1", "2", "3", "0"])
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

    /// The topics list leaves out the topics the user may not see: a group screen reads its topic alone, with its
    /// rights, without adding it to the list.
    func testFetchTopicReadsATopicAloneWithoutStoringIt() async throws {
        mockOctoService.injectNextGetResponse(.with {
            $0.octoObjectID = "hidden"
            $0.octoObject = .with {
                $0.id = "hidden"
                $0.descChildrenFeedID = "hidden-feed"
                $0.content = .with { $0.topic = .with { $0.name = "Hidden"; $0.followStatus = .topicNotFollowed } }
            }
            $0.requesterCtx = .with { $0.canAccess = true; $0.canCreateChildren = false }
        })

        let topic = try await topicsRepository.fetchTopic(uuid: "hidden")

        XCTAssertEqual(topic?.uuid, "hidden")
        XCTAssertEqual(topic?.name, "Hidden")
        XCTAssertEqual(topic?.feedId, "hidden-feed")
        XCTAssertEqual(topic?.permissions.canAccess, true)
        XCTAssertEqual(topic?.permissions.canCreateChildren, false)
        XCTAssertEqual(mockOctoService.getIncrementViewCounts, [false])
        XCTAssertTrue(topicsRepository.topics.isEmpty)
    }

    func testFetchTopicOfAnObjectThatIsNotATopicReturnsNil() async throws {
        mockOctoService.injectNextGetResponse(.with {
            $0.octoObjectID = "post"
            $0.octoObject = .with { $0.id = "post" }
        })

        let topic = try await topicsRepository.fetchTopic(uuid: "post")

        XCTAssertNil(topic)
    }

    func testFetchTopicNotFoundReturnsNil() async throws {
        mockOctoService.injectNextGetError(.notFound)

        let topic = try await topicsRepository.fetchTopic(uuid: "missing")

        XCTAssertNil(topic)
    }

    /// A refused read says the user may not read the topic, like a missing one: it is not a failed call.
    func testFetchTopicPermissionDeniedReturnsNil() async throws {
        mockOctoService.injectNextGetError(.permissionDenied(reason: nil))

        let topic = try await topicsRepository.fetchTopic(uuid: "hidden")

        XCTAssertNil(topic)
    }

    func testFetchTopicOtherErrorIsPassedOn() async {
        mockOctoService.injectNextGetError(.timeout)

        do throws(ServerCallError) {
            _ = try await topicsRepository.fetchTopic(uuid: "hidden")
            XCTFail("expected the error to be passed on")
        } catch {
            guard case .serverError = error else {
                XCTFail("expected a server error, got \(error)")
                return
            }
        }
    }

    /// A response sent with no session is accepted when it comes back before the guest session exists, but can be
    /// stored after the guest's own response: the groups are fetched again, so that the guest's permissions stay.
    func testTopicsAreFetchedAgainWhenTheSessionChangedBeforeTheyWereStored() async throws {
        let authProvider = try XCTUnwrap(
            injector.getInjected(identifiedBy: Injected.authenticatedCallProvider) as? MockAuthenticatedCallProvider)
        authProvider.isConnected = false
        injectRemoteTopic(canCreateChildren: false)
        injectRemoteTopic(canCreateChildren: true)
        // The mock has no interceptor to refuse the response: a session change during the call stands for one
        // between the response's acceptance and its storage.
        mockOctoService.onGetTopics = { authProvider.isConnected = true }

        let topics = try await topicsRepository.fetchTopics()

        XCTAssertEqual(mockOctoService.getTopicsCallCount, 2)
        XCTAssertEqual(topics.map(\.permissions.canCreateChildren), [true])
        try await assertWithTimeout { self.topicsRepository.topics.map(\.permissions.canCreateChildren) == [true] }
    }

    /// Like a replay, the groups are not fetched again for a fetch that was cancelled: nobody waits for them anymore.
    func testCancelledTopicsFetchIsNotSentAgain() async throws {
        let authProvider = try XCTUnwrap(
            injector.getInjected(identifiedBy: Injected.authenticatedCallProvider) as? MockAuthenticatedCallProvider)
        authProvider.isConnected = false
        injectRemoteTopic(canCreateChildren: false)
        // The session changes before the response is stored, and the screen that wanted the groups goes away.
        mockOctoService.onGetTopics = {
            authProvider.isConnected = true
            withUnsafeCurrentTask { $0?.cancel() }
        }

        let topics = try await topicsRepository.fetchTopics()

        // No `assertWithTimeout` here: its sleep throws in a cancelled task.
        XCTAssertEqual(mockOctoService.getTopicsCallCount, 1)
        XCTAssertEqual(topics.map(\.permissions.canCreateChildren), [false])
    }

    /// A response refused because the session changed during its call is sent again with the new session: the
    /// response is then the new session's, and the groups are not fetched a third time.
    func testReplayedTopicsAreNotFetchedAgain() async throws {
        let authProvider = try XCTUnwrap(
            injector.getInjected(identifiedBy: Injected.authenticatedCallProvider) as? MockAuthenticatedCallProvider)
        authProvider.isConnected = false
        mockOctoService.injectNextGetTopicsError(.unknown(RefreshingTokenError.userIdNotMatching))
        injectRemoteTopic(canCreateChildren: true)
        // The guest session appears while the first call is in flight, which is why its response is refused.
        mockOctoService.onGetTopics = { authProvider.isConnected = true }

        let topics = try await topicsRepository.fetchTopics()

        XCTAssertEqual(mockOctoService.getTopicsCallCount, 2)
        XCTAssertEqual(topics.map(\.permissions.canCreateChildren), [true])
    }

    func testTopicsAreFetchedOnceWhenTheSessionDidNotChange() async throws {
        injectRemoteTopic(canCreateChildren: true)

        try await topicsRepository.fetchTopics()

        XCTAssertEqual(mockOctoService.getTopicsCallCount, 1)
    }

    func testTopicsAreFetchedAgainABoundedNumberOfTimesWhileTheSessionKeepsChanging() async throws {
        let authProvider = try XCTUnwrap(
            injector.getInjected(identifiedBy: Injected.authenticatedCallProvider) as? MockAuthenticatedCallProvider)
        for _ in 0...maxSessionChangeReplays { injectRemoteTopic(canCreateChildren: true) }
        mockOctoService.onGetTopics = { authProvider.userId = UUID().uuidString }

        try await topicsRepository.fetchTopics()

        XCTAssertEqual(mockOctoService.getTopicsCallCount, maxSessionChangeReplays + 1)
    }

    private func injectRemoteTopic(canCreateChildren: Bool) {
        mockOctoService.injectNextGetTopicsResponse(.with {
            $0.topics = [.with {
                $0.createdAt = Date().timestampMs
                $0.id = "t1"
                $0.content = .with { $0.topic = .with { $0.name = "Topic"; $0.followStatus = .topicFollowed } }
            }]
            $0.topicsRequesterCtxs = [.with { $0.canAccess = true; $0.canCreateChildren = canCreateChildren }]
        })
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
