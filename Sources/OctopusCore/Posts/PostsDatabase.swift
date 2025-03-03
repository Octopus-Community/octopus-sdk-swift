//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import DependencyInjection

extension Injected {
    static let postsDatabase = Injector.InjectedIdentifier<PostsDatabase>()
}

class PostsDatabase: InjectableObject {
    typealias FeedItem = Post

    static let injectedIdentifier = Injected.postsDatabase
    
    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext

    init(injector: Injector) {
        coreDataStack = injector.getInjected(identifiedBy: Injected.coreDataStack)
        context = coreDataStack.saveContext
    }

    func postPublisher(uuid: String) -> AnyPublisher<StorablePost?, Error> {
        return context
            .publisher(request: PostEntity.fetchById(id: uuid)) {
                guard let postEntity = $0.first else { return [] }
                return [StorablePost(from: postEntity)]
            }
            .map(\.first)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func postsPublisher(ids: [String]) -> AnyPublisher<[StorablePost], Error> {
        return context
            .publisher(request: PostEntity.fetchAllByIds(ids: ids)) {
                $0.map { StorablePost(from: $0) }
                    .sorted { post1, post2 in
                        guard let index1 = ids.firstIndex(of: post1.uuid),
                              let index2 = ids.firstIndex(of: post2.uuid) else {
                            return false
                        }
                        return index1 < index2
                    }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func getMissingPosts(infos: [FeedItemInfo]) async throws -> [String] {
        let dict = Dictionary(infos.map { ($0.itemId, $0.updateDate) }, uniquingKeysWith: { (first, _) in first })
        return try await context.performAsync { [context] in
            let existingIds = try context
                .fetch(PostEntity.fetchAllByIds(ids: Array(dict.keys)))
                .filter { post in
                    let date = dict[post.uuid]!
                    return date.timeIntervalSince1970 <= post.updateTimestamp
                }
                .map { $0.uuid }
            return Array(Set(Array(dict.keys)).subtracting(existingIds))
        }
    }

    func getPosts(ids: [String]) async throws -> [StorablePost] {
        let fetchedPosts = try await context.performAsync { [context] in
            try context.fetch(PostEntity.fetchAllByIds(ids: ids))
                .map { StorablePost(from: $0) }
        }

        // return them in the same order as Ids
        return fetchedPosts.sorted { post1, post2 in
                guard let index1 = ids.firstIndex(of: post1.uuid),
                      let index2 = ids.firstIndex(of: post2.uuid) else {
                    return false
                }
                return index1 < index2
            }
    }
    
    func upsert(posts: [StorablePost]) async throws {
        try await context.performAsync { [context] in
            let request: NSFetchRequest<PostEntity> = PostEntity.fetchAll()
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(PostEntity.uuid),
                                            posts.map { $0.uuid })
            let existingPosts = try context.fetch(request)
            
            for post in posts {
                let postEntity: PostEntity
                if let existingPost = existingPosts.first(where: { $0.uuid == post.uuid }) {
                    postEntity = existingPost
                } else {
                    postEntity = PostEntity(context: context)
                }
                postEntity.uuid = post.uuid
                postEntity.headline = post.headline
                postEntity.text = post.text
                postEntity.mediasRelationship = NSOrderedSet(array: post.medias.map {
                    let mediaEntity = MediaEntity(context: context)
                    mediaEntity.url = $0.url
                    mediaEntity.type = $0.kind.entity.rawValue
                    mediaEntity.width = $0.size.width
                    mediaEntity.height = $0.size.height
                    return mediaEntity
                })
                postEntity.authorId = post.author?.uuid
                postEntity.authorNickname = post.author?.nickname
                postEntity.authorAvatarUrl = post.author?.avatarUrl
                postEntity.creationTimestamp = post.creationDate.timeIntervalSince1970
                postEntity.updateTimestamp = post.updateDate.timeIntervalSince1970
                postEntity.statusValue = post.status.rawValue
                postEntity.statusReasonCodes = post.statusReasons.storableCodes
                postEntity.statusReasonMessages = post.statusReasons.storableMessages
                postEntity.parentId = post.parentId
                if postEntity.descChildrenFeedId?.nilIfEmpty == nil || post.descCommentFeedId?.nilIfEmpty != nil {
                    postEntity.descChildrenFeedId = post.descCommentFeedId
                }
                if postEntity.ascChildrenFeedId?.nilIfEmpty == nil || post.ascCommentFeedId?.nilIfEmpty != nil {
                    postEntity.ascChildrenFeedId = post.ascCommentFeedId
                }

                if let aggregatedInfo = post.aggregatedInfo {
                    postEntity.viewCount = aggregatedInfo.viewCount
                    if post.userLikeId != nil {
                        postEntity.likeCount = max(aggregatedInfo.likeCount, 1)
                    } else {
                        postEntity.likeCount = aggregatedInfo.likeCount
                    }
                    postEntity.childCount = aggregatedInfo.childCount
                }

                postEntity.userLikeId = post.userLikeId
            }
            
            try context.save()
        }
    }

    func update(additionalData array: [(String, AggregatedInfo?, UserInteractions?)]) async throws {
        try await context.performAsync { [context] in
            let request: NSFetchRequest<PostEntity> = PostEntity.fetchAllByIds(ids: array.map(\.0))
            let existingPosts = try context.fetch(request)

            for additionalData in array {
                guard let postEntity = existingPosts.first(where: { $0.uuid == additionalData.0 }) else {
                    print("Developper error: updating additional data wihout post")
                    continue
                }
                if let aggregatedInfo = additionalData.1 {
                    postEntity.viewCount = aggregatedInfo.viewCount
                    if let userInteractions = additionalData.2, userInteractions.userLikeId != nil {
                        postEntity.likeCount = max(aggregatedInfo.likeCount, 1)
                    } else {
                        postEntity.likeCount = aggregatedInfo.likeCount
                    }
                    postEntity.childCount = aggregatedInfo.childCount
                }

                if let userInteractions = additionalData.2 {
                    postEntity.userLikeId = userInteractions.userLikeId
                }
            }

            try context.save()
        }
    }

    func incrementChildCount(by diff: Int, postId: String) async throws {
        try await context.performAsync { [context] in
            guard let existingPost = try context.fetch(PostEntity.fetchById(id: postId)).first else { return }
            existingPost.childCount = max(existingPost.childCount + diff, 0)
            try context.save()
        }
    }

    func updateLikeId(newId: String?, postId: String, updateLikeCount: Bool = true) async throws {
        try await context.performAsync { [context] in
            guard let existingPost = try context.fetch(PostEntity.fetchById(id: postId)).first else { return }
            existingPost.userLikeId = newId
            if updateLikeCount {
                let diff = newId != nil ? 1 : -1
                existingPost.likeCount = max(existingPost.likeCount + diff, 0)
            }
            try context.save()
        }
    }

    func delete(postId: String) async throws {
        try await context.performAsync { [context] in
            guard let existingPost = try context.fetch(PostEntity.fetchById(id: postId)).first else { return }
            context.delete(existingPost)
            try context.save()
        }
    }

    func deleteAll(except ids: [String]) async throws {
        try await context.performAsync { [context] in
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = PostEntity.fetchAllExcept(ids: ids) as! NSFetchRequest<NSFetchRequestResult>
            deleteRequest.includesPropertyValues = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            try context.execute(batchDeleteRequest)
        }
    }
}
