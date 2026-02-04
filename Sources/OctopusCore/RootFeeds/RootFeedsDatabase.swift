//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection

extension Injected {
    static let rootFeedsDatabase = Injector.InjectedIdentifier<RootFeedsDatabase>()
}

class RootFeedsDatabase: InjectableObject {
    static let injectedIdentifier = Injected.rootFeedsDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    func rootFeedsPublisher() -> AnyPublisher<[StorableRootFeed], Error> {
        return context
            .publisher(request: RootFeedEntity.fetchAllSorted()) {
                $0.map { StorableRootFeed(from: $0) }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func replaceAll(rootFeeds: [StorableRootFeed]) async throws {
        try await context.performAsync { [context] in

            // first delete all existing root feeds
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = RootFeedEntity.fetchAll() as! NSFetchRequest<NSFetchRequestResult>
            deleteRequest.includesPropertyValues = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            try context.execute(batchDeleteRequest)

            for (index, rootFeed) in rootFeeds.enumerated() {
                let rootFeedEntity = RootFeedEntity(context: context)

                rootFeedEntity.uuid = rootFeed.feedId
                rootFeedEntity.label = rootFeed.label
                rootFeedEntity.relatedTopicId = rootFeed.relatedTopicId
                rootFeedEntity.position = index
            }

            try context.save()
        }
    }
}
