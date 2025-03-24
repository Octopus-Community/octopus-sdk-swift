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
    
    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext
    
    init(injector: Injector) {
        coreDataStack = injector.getInjected(identifiedBy: Injected.coreDataStack)
        context = coreDataStack.saveContext
    }
    
    func topicsPublisher() -> AnyPublisher<[Topic], Error> {
        return context
            .publisher(request: TopicEntity.fetchAllAndSorted()) {
                $0.map { Topic(from: $0) }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func upsert(topics: [Topic]) async throws {
        try await context.performAsync { [context] in
            let context = context

            let existingTopicsCount = try context.count(for: TopicEntity.fetchAll())

            let request: NSFetchRequest<TopicEntity> = TopicEntity.fetchAll()
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(TopicEntity.uuid),
                                            topics.map { $0.uuid })
            let existingTopics = try context.fetch(request)

            for (index, topic) in topics.enumerated() {
                let topicEntity: TopicEntity
                if let existingTopic = existingTopics.first(where: { $0.uuid == topic.uuid }) {
                    topicEntity = existingTopic
                } else {
                    topicEntity = TopicEntity(context: context)
                }
                topicEntity.uuid = topic.uuid
                topicEntity.name = topic.name
                topicEntity.desc = topic.description
                topicEntity.parentId = topic.parentId
                topicEntity.position = existingTopicsCount + index
            }

            try context.save()
        }
    }

    func deleteAll() async throws {
        try await context.performAsync { [context] in
            let context = context
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: TopicEntity.fetchAllForDelete())
            try context.execute(deleteRequest)
        }
    }
}
