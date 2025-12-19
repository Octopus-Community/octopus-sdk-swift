//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let repliesDatabase = Injector.InjectedIdentifier<RepliesDatabase>()
}

class RepliesDatabase: ContentsDatabase<ReplyEntity>, InjectableObject {
    static let injectedIdentifier = Injected.repliesDatabase

    private let context: NSManagedObjectContext

    override init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
        super.init(injector: injector)
    }

    func repliesPublisher(ids: [String]) -> AnyPublisher<[StorableReply], Error> {
        return context
            .publisher(request: ReplyEntity.fetchAllByIds(ids: ids),
                       relatedTypes: [MinimalProfileEntity.self]) {
                $0.map { StorableReply(from: $0) }
                    .sorted { reply1, reply2 in
                        guard let index1 = ids.firstIndex(of: reply1.uuid),
                              let index2 = ids.firstIndex(of: reply2.uuid) else {
                            return false
                        }
                        return index1 < index2
                    }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func getReplies(ids: [String]) async throws -> [StorableReply] {
        let fetchedReplies = try await context.performAsync { [context] in
            try context.fetch(ReplyEntity.fetchAllByIds(ids: ids))
                .map { StorableReply(from: $0) }
        }

        // return them in the same order as Ids
        return fetchedReplies.sorted { reply1, reply2 in
                guard let index1 = ids.firstIndex(of: reply1.uuid),
                      let index2 = ids.firstIndex(of: reply2.uuid) else {
                    return false
                }
                return index1 < index2
            }
    }

    func upsert(replies: [StorableReply]) async throws {
        try await context.performAsync { [context] in
            let context = context
            let request: NSFetchRequest<ReplyEntity> = ReplyEntity.fetchAll()
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(ReplyEntity.uuid),
                                            replies.map { $0.uuid })
            let existingReplies = try context.fetch(request)

            for reply in replies {
                let replyEntity: ReplyEntity
                if let existingReply = existingReplies.first(where: { $0.uuid == reply.uuid }) {
                    replyEntity = existingReply
                } else {
                    replyEntity = ReplyEntity(context: context)
                }
                try replyEntity.fill(with: reply, context: context)
            }
            
            try context.save()
        }
    }

    func getMissingReplies(infos: [FeedItemInfo]) async throws -> [String] {
        return try await getMissingContents(infos: infos)
    }

    func delete(replyId: String) async throws {
        try await super.delete(contentId: replyId)
    }
}
