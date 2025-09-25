//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import os
import OctopusDependencyInjection

class ContentsDatabase<Content: FetchableContentEntity>: OctoObjectsDatabase {
    private let context: NSManagedObjectContext

    override init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
        super.init(injector: injector)
    }

    func getMissingContents(infos: [FeedItemInfo]) async throws -> [String] {
        let dict = Dictionary(uniqueKeysWithValues: infos.map { ($0.itemId, $0.updateDate) })
        let existingIds = try await context.performAsync { [context] in
            try context.fetch(Content.fetchAllByIds(ids: Array(dict.keys)))
                .filter { content in
                    let date = dict[content.uuid]!
                    return date.timeIntervalSince1970 <= content.updateTimestamp
                }
                .map { $0.uuid }
        }
        return Array(Set(Array(dict.keys)).subtracting(existingIds))
    }

    func delete(contentId: String) async throws {
        try await context.performAsync { [context] in
            let context = context
            guard let existingContent = try context.fetch(Content.fetchById(id: contentId)).first else { return }
            context.delete(existingContent)
            try context.save()
        }
    }

    func deleteAll(except ids: [String]) async throws {
        try await context.performAsync { [context] in
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = Content.fetchAllExcept(ids: ids) as! NSFetchRequest<NSFetchRequestResult>
            deleteRequest.includesPropertyValues = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            try context.execute(batchDeleteRequest)
        }
    }
}
