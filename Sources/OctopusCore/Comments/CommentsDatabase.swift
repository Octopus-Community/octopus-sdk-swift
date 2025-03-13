//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import DependencyInjection

extension Injected {
    static let commentsDatabase = Injector.InjectedIdentifier<CommentsDatabase>()
}

class CommentsDatabase: InjectableObject {
    static let injectedIdentifier = Injected.commentsDatabase
    
    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext

    init(injector: Injector) {
        coreDataStack = injector.getInjected(identifiedBy: Injected.coreDataStack)
        context = coreDataStack.saveContext
    }

    func commentsPublisher(ids: [String]) -> AnyPublisher<[Comment], Error> {
        return context
            .publisher(request: CommentEntity.fetchAllByIds(ids: ids)) {
                $0.map { Comment(from: $0) }
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

    func getMissingComments(infos: [FeedItemInfo]) async throws -> [String] {
        let dict = Dictionary(uniqueKeysWithValues: infos.map { ($0.itemId, $0.updateDate) })
        let existingIds = try await context.performAsync { [context] in
            try context.fetch(CommentEntity.fetchAllByIds(ids: Array(dict.keys)))
                .filter { post in
                    let date = dict[post.uuid]!
                    return date.timeIntervalSince1970 <= post.updateTimestamp
                }
                .map { $0.uuid }
        }
        return Array(Set(Array(dict.keys)).subtracting(existingIds))
    }

    func getComments(ids: [String]) async throws -> [Comment] {
        let mainContext = coreDataStack.persistentContainer.viewContext
        let fetchedPosts = try await mainContext.performAsync { [mainContext] in
            try mainContext.fetch(CommentEntity.fetchAllByIds(ids: ids))
                .map { Comment(from: $0) }
        }

        // return them in the same order as Ids
        return fetchedPosts.sorted { comment1, comment2 in
                guard let index1 = ids.firstIndex(of: comment1.uuid),
                      let index2 = ids.firstIndex(of: comment2.uuid) else {
                    return false
                }
                return index1 < index2
            }
    }

    func upsert(comments: [Comment]) async throws {
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
                commentEntity.uuid = comment.uuid
                commentEntity.text = comment.text
                commentEntity.mediasRelationship = NSOrderedSet(array: comment.medias.map {
                    let mediaEntity = MediaEntity(context: context)
                    mediaEntity.url = $0.url
                    mediaEntity.type = $0.kind.entity.rawValue
                    mediaEntity.width = $0.size.width
                    mediaEntity.height = $0.size.height
                    return mediaEntity
                })
                commentEntity.authorId = comment.author?.uuid
                commentEntity.authorNickname = comment.author?.nickname
                commentEntity.authorAvatarUrl = comment.author?.avatarUrl
                commentEntity.creationTimestamp = comment.creationDate.timeIntervalSince1970
                commentEntity.updateTimestamp = comment.updateDate.timeIntervalSince1970
                commentEntity.statusValue = comment.innerStatus.rawValue
                commentEntity.statusReasonCodes = comment.innerStatusReasons.storableCodes
                commentEntity.statusReasonMessages = comment.innerStatusReasons.storableMessages
                commentEntity.parentId = comment.parentId
            }
            
            try context.save()
        }
    }

    func update(additionalData array: [(String, AggregatedInfo?, UserInteractions?)]) async throws {
        try await context.performAsync { [context] in
            let context = context
            let request: NSFetchRequest<CommentEntity> = CommentEntity.fetchAllByIds(ids: array.map(\.0))
            let existingPosts = try context.fetch(request)

            for additionalData in array {
                guard let postEntity = existingPosts.first(where: { $0.uuid == additionalData.0 }) else {
                    if #available(iOS 14, *) { Logger.comments.debug("Developper error: updating additional data wihout comment") }
                    continue
                }
                if let aggregatedInfo = additionalData.1 {
                    postEntity.likeCount = aggregatedInfo.likeCount
                }

                if let userInteractions = additionalData.2 {
                    postEntity.userLikeId = userInteractions.userLikeId
                }
            }

            try context.save()
        }
    }

    func updateLikeId(newId: String?, commentId: String, updateLikeCount: Bool = true) async throws {
        try await context.performAsync { [context] in
            let context = context
            guard let existingComment = try context.fetch(CommentEntity.fetchById(id: commentId)).first else { return }
            existingComment.userLikeId = newId
            if updateLikeCount {
                let diff = newId != nil ? 1 : -1
                existingComment.likeCount = max(existingComment.likeCount + diff, 0)
            }
            try context.save()
        }
    }

    func delete(commentId: String) async throws {
        try await context.performAsync { [context] in
            let context = context
            guard let existingComment = try context.fetch(CommentEntity.fetchById(id: commentId)).first else { return }
            context.delete(existingComment)
            try context.save()
        }
    }

    func deleteAll(except ids: [String]) async throws {
        try await context.performAsync { [context] in
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = CommentEntity.fetchAllExcept(ids: ids) as! NSFetchRequest<NSFetchRequestResult>
            deleteRequest.includesPropertyValues = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            try context.execute(batchDeleteRequest)
        }
    }
}
