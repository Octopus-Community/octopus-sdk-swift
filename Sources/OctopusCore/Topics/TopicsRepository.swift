//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import RemoteClient
import GrpcModels
import DependencyInjection

public struct Topic: Equatable, Sendable {
    public let uuid: String
    public let name: String
    public let description: String
    public let parentId: String
}

extension Injected {
    static let topicsRepository = Injector.InjectedIdentifier<TopicsRepository>()
}

public class TopicsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.topicsRepository

    @Published public private(set) var topics: [Topic] = []

    private let topicsDatabase: TopicsDatabase
    private let remoteClient: RemoteClient
    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        topicsDatabase = injector.getInjected(identifiedBy: Injected.topicsDatabase)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)

        topicsDatabase.topicsPublisher()
            .replaceError(with: [])
            .removeDuplicates()
            .sink { [unowned self] in
                topics = $0
            }.store(in: &storage)
    }

    public func fetchTopics() async throws {
        let response = try await remoteClient.octoService.getTopics(authenticationMethod: .notAuthenticated)
        let topics = response.topics.compactMap { Topic(from: $0) }
        try await topicsDatabase.deleteAll()
        try await topicsDatabase.upsert(topics: topics)
    }
}

// TODO: move it in a TopicTransformation file
extension Topic {
    init(from entity: TopicEntity) {
        uuid = entity.uuid
        name = entity.name
        description = entity.desc
        parentId = entity.parentId
    }

    init?(from octoTopic: Com_Octopuscommunity_OctoObject) {
        guard octoTopic.hasContent && octoTopic.content.hasTopic else { return nil }
        uuid = octoTopic.id
        name = octoTopic.content.topic.name
        description = octoTopic.content.topic.description_p
        parentId = octoTopic.parentID
    }
}
