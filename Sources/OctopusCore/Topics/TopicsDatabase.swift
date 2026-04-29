//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection

extension Injected {
    static let topicsDatabase = Injector.InjectedIdentifier<TopicsDatabase>()
}

class TopicsDatabase: InjectableObject {
    static let injectedIdentifier = Injected.topicsDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    func topicsPublisher() -> AnyPublisher<[StorableTopic], Error> {
        return context
            .publisher(request: TopicEntity.fetchAllAndSorted()) {
                $0.map { StorableTopic(from: $0) }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func replaceAll(topics: [StorableTopic]) async throws {
        try await context.performAsync { [context] in

            // first delete all existing topics and existing sections
            let deleteSectionRequest = NSBatchDeleteRequest(fetchRequest: SectionEntity.fetchAllForDelete())
            try context.execute(deleteSectionRequest)

            let deleteTopicRequest = NSBatchDeleteRequest(fetchRequest: TopicEntity.fetchAllForDelete())
            try context.execute(deleteTopicRequest)

            for (index, topic) in topics.enumerated() {
                let topicEntity = TopicEntity(context: context)
                try topicEntity.fill(with: topic, position: index, context: context)
            }

            try context.save()
        }
    }

    func changeIsFollowing(topicId: String, isFollowing: Bool) async throws {
        try await context.performAsync { [context] in
            guard let existingTopic = try context.fetch(TopicEntity.fetchById(id: topicId)).first else {
                throw InternalError.objectNotFound
            }

            if isFollowing {
                existingTopic.followStatusValue = StorableFollowStatus.followed.rawValue
            } else {
                existingTopic.followStatusValue = StorableFollowStatus.notFollowed.rawValue
            }

            try context.save()
        }
    }
}
