//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let postsDatabase = Injector.InjectedIdentifier<PostsDatabase>()
}

class PostsDatabase: ContentsDatabase<PostEntity>, InjectableObject {

    static let injectedIdentifier = Injected.postsDatabase
    
    private let context: NSManagedObjectContext

    override init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
        super.init(injector: injector)
    }

    func postPublisher(uuid: String) -> AnyPublisher<StorablePost?, Error> {
        (context
            .publisher(request: PostEntity.fetchById(id: uuid),
                       relatedTypes: [MinimalProfileEntity.self]) {
                guard let postEntity = $0.first else { return [] }
                return [StorablePost(from: postEntity)]
            } as AnyPublisher<[StorablePost], Error>
        )
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

    func clientObjectRelatedPostPublisher(objectId: String) -> AnyPublisher<StorablePost?, Error> {
        (context
            .publisher(request: PostEntity.fetchByClientObjectId(id: objectId)) { posts in
                let mostRecentPost = posts.max { $0.updateTimestamp < $1.updateTimestamp }
                guard let mostRecentPost else {
                    return []
                }
                return [StorablePost(from: mostRecentPost)]
            } as AnyPublisher<[StorablePost], Error>
        )
        .map(\.first)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    func getClientObjectRelatedPost(objectId: String) async throws -> StorablePost? {
        return try await context.performAsync { [context] in
            let posts = try context.fetch(PostEntity.fetchByClientObjectId(id: objectId))
            let mostRecentPost = posts.max { $0.updateTimestamp < $1.updateTimestamp }
            guard let mostRecentPost else {
                return nil
            }
            return StorablePost(from: mostRecentPost)
        }
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
            let request = PostEntity.fetchAllByIds(ids: posts.map(\.uuid))
            let existingPosts = try context.fetch(request)
            
            for post in posts {
                let postEntity: PostEntity
                if let existingPost = existingPosts.first(where: { $0.uuid == post.uuid }) {
                    postEntity = existingPost
                } else {
                    postEntity = PostEntity(context: context)
                }
                try postEntity.fill(with: post, context: context)
            }
            
            try context.save()
        }
    }

    func updateVote(answerId: String?, postId: String, updatePollCount: Bool = true) async throws {
        try await context.performAsync { [context] in
            guard let existingPost = try context.fetch(PostEntity.fetchById(id: postId)).first else { return }
            let previousVoteId = existingPost.userPollVoteId
            existingPost.userPollVoteId = answerId
            if updatePollCount {
                if previousVoteId != nil {
                    existingPost.pollTotalVoteCount = max(existingPost.pollTotalVoteCount - 1, 0)
                }
                if answerId != nil {
                    existingPost.pollTotalVoteCount += 1
                }
                var isModified = false
                var newPollResults = existingPost.pollResults ?? []
                for pollResult in existingPost.pollResults ?? [] {
                    if previousVoteId == pollResult.optionId {
                        pollResult.voteCount = max(pollResult.voteCount - 1, 0)
                    }
                    if answerId == pollResult.optionId {
                        pollResult.voteCount = pollResult.voteCount + 1
                        isModified = true
                    }
                    newPollResults.append(pollResult)
                }
                // Since pollResults might be empty, add the vote if needed
                if let answerId, !isModified {
                    let pollOptionResultEntity = PollOptionResultEntity(context: context)
                    pollOptionResultEntity.optionId = answerId
                    pollOptionResultEntity.voteCount = 1
                    newPollResults.append(pollOptionResultEntity)
                }
                existingPost.pollOptionResultsRelationship = NSOrderedSet(array: newPollResults)
            }
            try context.save()
        }
    }
}
