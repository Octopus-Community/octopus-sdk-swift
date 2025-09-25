//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import os
import OctopusDependencyInjection

class OctoObjectsDatabase {
    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    func update(additionalData array: [(String, AggregatedInfo?, UserInteractions?)]) async throws {
        try await context.performAsync { [context] in
            let context = context
            let request = OctoObjectEntity.fetchAllGenericByIds(ids: array.map(\.0))
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
            guard let existingContent = try context.fetch(OctoObjectEntity.fetchGenericById(id: contentId)).first else {
                return
            }
            existingContent.childCount = max(existingContent.childCount + diff, 0)
            try context.save()
        }
    }

    func update(userReaction: UserReaction?, contentId: String, updateReactionCount: Bool = true) async throws {
        try await context.performAsync { [context] in
            let context = context
            guard let existingContent = try context.fetch(OctoObjectEntity.fetchGenericById(id: contentId)).first else {
                return
            }
            let previousUserReactionKind = existingContent.userReactionKind
            let newReactionKind = userReaction?.kind.unicode
            existingContent.userReactionId = userReaction?.id
            existingContent.userReactionKind = userReaction?.kind.unicode
            if updateReactionCount, previousUserReactionKind != newReactionKind {
                var updatedReactions = [ContentReactionEntity]()
                for existingReaction in existingContent.reactions {
                    let reactionToSave: ContentReactionEntity
                    if existingReaction.reactionKind == previousUserReactionKind {
                        reactionToSave = ContentReactionEntity(context: context)
                        reactionToSave.reactionKind = existingReaction.reactionKind
                        reactionToSave.count = max(existingReaction.count - 1, 0)
                    } else if let newReactionKind, existingReaction.reactionKind == newReactionKind {
                        reactionToSave = ContentReactionEntity(context: context)
                        reactionToSave.reactionKind = existingReaction.reactionKind
                        reactionToSave.count = existingReaction.count + 1
                    } else {
                        reactionToSave = existingReaction
                    }

                    updatedReactions.append(reactionToSave)
                }
                // if the new reaction was not part of existingContent.reactions, add it to updatedReactions
                if let newReactionKind,
                   !updatedReactions.contains(where: { $0.reactionKind == newReactionKind }) {
                    let reactionToSave = ContentReactionEntity(context: context)
                    reactionToSave.reactionKind = newReactionKind
                    reactionToSave.count = 1
                    updatedReactions.append(reactionToSave)
                }
                existingContent.reactionsRelationship = NSOrderedSet(array: updatedReactions)
            }
            try context.save()
        }
    }

    func resetUserInteractions() async throws {
        try await context.performAsync { [context] in
            let context = context
            let request = OctoObjectEntity.fetchAllGeneric()
            let existingContents = try context.fetch(request)

            for existingContent in existingContents {
                existingContent.fill(aggregatedInfo: nil, userInteractions: .empty, context: context)
            }
            try context.save()
        }
    }
}
