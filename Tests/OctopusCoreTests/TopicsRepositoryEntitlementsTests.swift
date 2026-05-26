//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

final class TopicsRepositoryEntitlementsTests: XCTestCase {
    private var topicsRepository: TopicsRepository!
    private var mockOctoService: MockOctoService!
    private var injector: Injector!

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
    }

    func testZipsRequesterCtxsByIndex() async throws {
        injectTopicsWithCtxs([
            (uuid: "open-group", canAccess: true, canCreateChildren: true),
            (uuid: "locked-group", canAccess: false, canCreateChildren: false)
        ])

        let topics = try await topicsRepository.fetchTopics()

        XCTAssertEqual(topics.count, 2)
        XCTAssertEqual(topics[0].uuid, "open-group")
        XCTAssertTrue(topics[0].permissions.canAccess)
        XCTAssertTrue(topics[0].permissions.canCreateChildren)
        XCTAssertEqual(topics[1].uuid, "locked-group")
        XCTAssertFalse(topics[1].permissions.canAccess)
        XCTAssertFalse(topics[1].permissions.canCreateChildren)
    }

    func testEmptyRequesterCtxsDefaultsToOpen() async throws {
        injectTopicsWithCtxs([
            (uuid: "g1", canAccess: nil, canCreateChildren: nil),
            (uuid: "g2", canAccess: nil, canCreateChildren: nil)
        ], includeCtxs: false)

        let topics = try await topicsRepository.fetchTopics()

        XCTAssertEqual(topics.count, 2)
        XCTAssertTrue(topics[0].permissions.canAccess)
        XCTAssertTrue(topics[0].permissions.canCreateChildren)
        XCTAssertTrue(topics[1].permissions.canAccess)
        XCTAssertTrue(topics[1].permissions.canCreateChildren)
    }

    func testMismatchedLengthDefaultsMissingToOpen() async throws {
        // 3 topics, only 2 ctxs — third topic falls to UserPermissions.default
        let ctxs: [(uuid: String, canAccess: Bool?, canCreateChildren: Bool?)] = [
            (uuid: "a", canAccess: false, canCreateChildren: false),
            (uuid: "b", canAccess: true, canCreateChildren: false)
        ]
        injectTopicsWithExtraTopics(
            ctxs: ctxs,
            extraTopicUuids: ["c"]
        )

        let topics = try await topicsRepository.fetchTopics()

        XCTAssertEqual(topics.count, 3)
        XCTAssertFalse(topics[0].permissions.canAccess)
        XCTAssertTrue(topics[1].permissions.canAccess)
        XCTAssertFalse(topics[1].permissions.canCreateChildren)
        // Third topic has no ctx → defaults open
        XCTAssertTrue(topics[2].permissions.canAccess)
        XCTAssertTrue(topics[2].permissions.canCreateChildren)
    }

    // MARK: - canCreateAnyPost

    func testCanCreateAnyPostDefaultsTrueBeforeTopicsLoad() {
        // No topics loaded yet — property should default to true.
        XCTAssertTrue(topicsRepository.canCreateAnyPost)
    }

    func testCanCreateAnyPostTrueWhenAtLeastOneTopicIsFullyWritable() async throws {
        injectTopicsWithCtxs([
            (uuid: "locked", canAccess: false, canCreateChildren: false),
            (uuid: "open", canAccess: true, canCreateChildren: true)
        ])
        _ = try await topicsRepository.fetchTopics()

        try await expectWithTimeout(timeout: 5, topicsRepository.canCreateAnyPost)
    }

    func testCanCreateAnyPostFalseWhenNoTopicIsFullyWritable() async throws {
        injectTopicsWithCtxs([
            (uuid: "no-access", canAccess: false, canCreateChildren: true),
            (uuid: "no-create", canAccess: true, canCreateChildren: false)
        ])
        _ = try await topicsRepository.fetchTopics()

        try await expectWithTimeout(timeout: 5, !topicsRepository.canCreateAnyPost)
    }

    func testCanCreateAnyPostUpdatesDynamicallyWhenTopicsChange() async throws {
        // First load: all restricted → canCreateAnyPost becomes false.
        injectTopicsWithCtxs([
            (uuid: "locked", canAccess: false, canCreateChildren: false)
        ])
        _ = try await topicsRepository.fetchTopics()
        try await expectWithTimeout(timeout: 5, !topicsRepository.canCreateAnyPost)

        // Second load: one writable topic added → canCreateAnyPost becomes true.
        injectTopicsWithCtxs([
            (uuid: "locked", canAccess: false, canCreateChildren: false),
            (uuid: "open", canAccess: true, canCreateChildren: true)
        ])
        _ = try await topicsRepository.fetchTopics()
        try await expectWithTimeout(timeout: 5, topicsRepository.canCreateAnyPost)
    }

    // MARK: - Helpers

    private func injectTopicsWithCtxs(
        _ items: [(uuid: String, canAccess: Bool?, canCreateChildren: Bool?)],
        includeCtxs: Bool = true
    ) {
        let topics = items.map { item in
            Com_Octopuscommunity_OctoObject.with {
                $0.createdAt = Date().timestampMs
                $0.id = item.uuid
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = item.uuid
                        $0.description_p = ""
                        $0.followStatus = .topicFollowed
                    }
                }
            }
        }
        let ctxs: [Com_Octopuscommunity_RequesterCtx] = includeCtxs ? items.map { item in
            Com_Octopuscommunity_RequesterCtx.with { ctx in
                if let canAccess = item.canAccess { ctx.canAccess = canAccess }
                if let canCreateChildren = item.canCreateChildren { ctx.canCreateChildren = canCreateChildren }
            }
        } : []
        mockOctoService.injectNextGetTopicsResponse(.with {
            $0.topics = topics
            $0.topicsRequesterCtxs = ctxs
        })
    }

    private func injectTopicsWithExtraTopics(
        ctxs items: [(uuid: String, canAccess: Bool?, canCreateChildren: Bool?)],
        extraTopicUuids: [String]
    ) {
        let topicProtos: [Com_Octopuscommunity_OctoObject] =
            (items.map { $0.uuid } + extraTopicUuids).map { uuid in
                Com_Octopuscommunity_OctoObject.with {
                    $0.createdAt = Date().timestampMs
                    $0.id = uuid
                    $0.content = .with {
                        $0.topic = .with {
                            $0.name = uuid
                            $0.description_p = ""
                            $0.followStatus = .topicFollowed
                        }
                    }
                }
            }
        let ctxProtos: [Com_Octopuscommunity_RequesterCtx] = items.map { item in
            Com_Octopuscommunity_RequesterCtx.with { ctx in
                if let canAccess = item.canAccess { ctx.canAccess = canAccess }
                if let canCreateChildren = item.canCreateChildren { ctx.canCreateChildren = canCreateChildren }
            }
        }
        mockOctoService.injectNextGetTopicsResponse(.with {
            $0.topics = topicProtos
            $0.topicsRequesterCtxs = ctxProtos
        })
    }
}
