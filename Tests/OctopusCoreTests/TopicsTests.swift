//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import DependencyInjection
import RemoteClient
import GrpcModels
@testable import OctopusCore

class TopicsTests: XCTestCase {
    /// Object that is tested
    private var topicsRepository: TopicsRepository!

    private var mockOctoService: MockOctoService!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
        injector.register { TopicsDatabase(injector: $0) }
        injector.registerMocks(.remoteClient)

        topicsRepository = TopicsRepository(injector: injector)
        mockOctoService = (injector.getInjected(identifiedBy: Injected.remoteClient).octoService as! MockOctoService)
    }

    func testGetLocalAndRemoteTopics() async throws {
        let localExpectation = XCTestExpectation(description: "DB updated")

        topicsRepository.$topics
            .sink { topics in
                if topics.first?.name == "First Topic" {
                    localExpectation.fulfill()
                }
            }.store(in: &storage)

        injectRemoteItems([
            .init(uuid: "1", name: "First Topic", description: "Desc", parentId: "topics")
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
            .init(uuid: "1", name: "1st Topic", description: "", parentId: ""),
            .init(uuid: "2", name: "2nd Topic", description: "", parentId: ""),
            .init(uuid: "3", name: "3rd Topic", description: "", parentId: ""),
            .init(uuid: "0", name: "4th Topic", description: "", parentId: ""),
        ])
        try await topicsRepository.fetchTopics()

        await fulfillment(of: [localExpectation], timeout: 0.5)
        XCTAssertEqual(topics.map { $0.uuid }, ["1", "2", "3", "0"])
    }

    func injectRemoteItems(_ items: [Topic]) {
        let topics = items.map { item in
            Com_Octopuscommunity_OctoObject.with {
                $0.createdAt = Date().timestampMs
                $0.id = item.uuid
                $0.parentID = item.parentId
                $0.createdBy = .with {
                    $0.profileID = item.uuid
                    $0.nickname = item.name
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = item.name
                        $0.description_p = item.description
                    }
                }
            }
        }
        mockOctoService.injectNextGetTopicsResponse(.with { $0.topics = topics })
    }
}
