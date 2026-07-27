//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

/// Tests the `@_spi`-exposed debug affordance that redistributes topics into mock client sections so
/// the sample can exercise the sectioned group-list rendering without a backend serving sections.
final class TopicsRepositoryDebugSectionsTests: XCTestCase {
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

    func testNoOverrideKeepsBackendSections() async throws {
        injectSectionlessTopics(["a", "b", "c"])

        let topics = try await topicsRepository.fetchTopics()

        XCTAssertEqual(topics.count, 3)
        XCTAssertTrue(topics.allSatisfy { $0.sections.isEmpty })
    }

    func testOverrideLeavesFirstTopicSectionlessAndDistributesTheRest() async throws {
        topicsRepository.debugOverrideTopicSections(mockSectionNames: ["Popular", "Discover"])
        injectSectionlessTopics(["a", "b", "c", "d", "e"])

        let topics = try await topicsRepository.fetchTopics()

        XCTAssertEqual(topics.count, 5)
        // First topic renders the leading no-section block (no separator above it).
        XCTAssertTrue(topics[0].sections.isEmpty)
        // Remaining topics round-robin across the two mock sections.
        XCTAssertEqual(topics[1].sections.map(\.name), ["Popular"])
        XCTAssertEqual(topics[2].sections.map(\.name), ["Discover"])
        XCTAssertEqual(topics[3].sections.map(\.name), ["Popular"])
        XCTAssertEqual(topics[4].sections.map(\.name), ["Discover"])
    }

    func testClearingOverrideRestoresSectionlessTopics() async throws {
        topicsRepository.debugOverrideTopicSections(mockSectionNames: ["Popular"])
        injectSectionlessTopics(["a", "b"])
        var topics = try await topicsRepository.fetchTopics()
        XCTAssertEqual(topics[1].sections.map(\.name), ["Popular"])

        topicsRepository.debugOverrideTopicSections(mockSectionNames: [])
        injectSectionlessTopics(["a", "b"])
        topics = try await topicsRepository.fetchTopics()
        XCTAssertTrue(topics.allSatisfy { $0.sections.isEmpty })
    }

    // MARK: - Helpers

    private func injectSectionlessTopics(_ uuids: [String]) {
        let topics = uuids.map { uuid in
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
        mockOctoService.injectNextGetTopicsResponse(.with {
            $0.topics = topics
        })
    }
}
