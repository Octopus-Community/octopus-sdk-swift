//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let commentsDatabase = Injector.InjectedIdentifier<CommentsDatabase>()
}

class CommentsDatabase: ContentsDatabase<CommentEntity>, InjectableObject {
    static let injectedIdentifier = Injected.commentsDatabase
    
    private let context: NSManagedObjectContext

    override init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
        super.init(injector: injector)
    }

    func commentPublisher(uuid: String) -> AnyPublisher<StorableComment?, Error> {
        (context
            .publisher(request: CommentEntity.fetchById(id: uuid)) {
                guard let commentEntity = $0.first else { return [] }
                return [StorableComment(from: commentEntity)]
            } as AnyPublisher<[StorableComment], Error>
        )
        .map(\.first)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    func commentsPublisher(ids: [String]) -> AnyPublisher<[StorableComment], Error> {
        return context
            .publisher(request: CommentEntity.fetchAllByIds(ids: ids)) {
                $0.map { StorableComment(from: $0) }
                    .sorted { comment1, comment2 in
                        guard let index1 = ids.firstIndex(of: comment1.uuid),
                              let index2 = ids.firstIndex(of: comment2.uuid) else {
                            return false
                        }
                        return index1 < index2
                    }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func getComments(ids: [String]) async throws -> [StorableComment] {
        let fetchedComments = try await context.performAsync { [context] in
            try context.fetch(CommentEntity.fetchAllByIds(ids: ids))
                .map { StorableComment(from: $0) }
        }

        // return them in the same order as Ids
        return fetchedComments.sorted { comment1, comment2 in
                guard let index1 = ids.firstIndex(of: comment1.uuid),
                      let index2 = ids.firstIndex(of: comment2.uuid) else {
                    return false
                }
                return index1 < index2
            }
    }

    func upsert(comments: [StorableComment]) async throws {
        try await context.performAsync { [context] in
            let context = context
            let request: NSFetchRequest<CommentEntity> = CommentEntity.fetchAll()
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(CommentEntity.uuid),
                                            comments.map { $0.uuid })
            let existingComments = try context.fetch(request)

            for comment in comments {
                let commentEntity: CommentEntity
                if let existingComment = existingComments.first(where: { $0.uuid == comment.uuid }) {
                    commentEntity = existingComment
                } else {
                    commentEntity = CommentEntity(context: context)
                }
                commentEntity.fill(with: comment, context: context)
            }
            
            try context.save()
        }
    }

    func getMissingComments(infos: [FeedItemInfo]) async throws -> [String] {
        return try await getMissingContents(infos: infos)
    }

    func updateLikeId(newId: String?, commentId: String, updateLikeCount: Bool = true) async throws {
        try await super.updateLikeId(newId: newId, contentId: commentId, updateLikeCount: updateLikeCount)
    }

    func delete(commentId: String) async throws {
        try await super.delete(contentId: commentId)
    }
}
