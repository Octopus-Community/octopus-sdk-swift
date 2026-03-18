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
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
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

        await fulfillment(of: [localExpectation], timeout: 0.5)
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

        await fulfillment(of: [localExpectation], timeout: 0.5)
        XCTAssertEqual(topics.map { $0.uuid }, ["1", "2", "3", "0"])
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
