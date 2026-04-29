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
            try context.chunkedFetch(ids: Array(dict.keys)) { chunk in
                Content.fetchAllByIds(ids: chunk)
            }
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

    func deleteAll(except idsToKeep: [String]) async throws {
        try await context.performAsync { [context] in
            // Lightweight fetch to get only UUIDs of entities eligible for deletion
            let entityName = Content.fetchAll().entityName!
            let dictionaryRequest = NSFetchRequest<NSDictionary>(entityName: entityName)
            dictionaryRequest.resultType = .dictionaryResultType
            dictionaryRequest.propertiesToFetch = ["uuid"]
            dictionaryRequest.predicate = Content.additionalDeletionPredicate

            let results = try context.fetch(dictionaryRequest)
            let allDeletableIds = results.compactMap { $0["uuid"] as? String }

            // Compute IDs to delete by subtracting the keep-set
            let keepSet = Set(idsToKeep)
            let idsToDelete = allDeletableIds.filter { !keepSet.contains($0) }

            // Batch delete in chunks to stay within SQLite's variable limit
            try context.chunkedBatchDelete(ids: idsToDelete) { chunk in
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                request.predicate = NSPredicate(format: "%K IN %@", "uuid", chunk)
                return request
            }
        }
    }
}
