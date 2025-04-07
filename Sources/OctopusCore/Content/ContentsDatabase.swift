//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import os
import OctopusDependencyInjection

class ContentsDatabase<Content: FetchableContentEntity> {
    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext

    init(injector: Injector) {
        coreDataStack = injector.getInjected(identifiedBy: Injected.coreDataStack)
        context = coreDataStack.saveContext
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

    func update(additionalData array: [(String, AggregatedInfo?, UserInteractions?)]) async throws {
        try await context.performAsync { [context] in
            let context = context
            let request = Content.fetchAllByIds(ids: array.map(\.0))
            let existingContents = try context.fetch(request)

            for additionalData in array {
                guard let contentEntity = existingContents.first(where: { $0.uuid == additionalData.0 }) else {
                    if #available(iOS 14, *) {
                        Logger.content.debug("Developper error: updating additional data without content")
                    }
                    continue
                }
                contentEntity.fill(aggregatedInfo: additionalData.1, userInteractions: additionalData.2,
                                   context: context)
            }
            try context.save()
        }
    }

    func incrementChildCount(by diff: Int, contentId: String) async throws {
        try await context.performAsync { [context] in
            guard let existingContent = try context.fetch(Content.fetchById(id: contentId)).first else { return }
            existingContent.childCount = max(existingContent.childCount + diff, 0)
            try context.save()
        }
    }

    func updateLikeId(newId: String?, contentId: String, updateLikeCount: Bool = true) async throws {
        try await context.performAsync { [context] in
            let context = context
            guard let existingContent = try context.fetch(Content.fetchById(id: contentId)).first else { return }
            existingContent.userLikeId = newId
            if updateLikeCount {
                let diff = newId != nil ? 1 : -1
                existingContent.likeCount = max(existingContent.likeCount + diff, 0)
            }
            try context.save()
        }
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
