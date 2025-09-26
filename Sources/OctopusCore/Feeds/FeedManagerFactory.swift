//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection
import Combine

enum PostsFeedManager {
    private class ProxyFeedItemDatabase: FeedItemsDatabase {
        typealias FeedItem = Post

        private let postsDatabase: PostsDatabase
        private let commentsDatabase: CommentsDatabase
        private let commentFeedsStore: CommentFeedsStore
        private let replyFeedsStore: ReplyFeedsStore
        private let blockedUserIdsProvider: BlockedUserIdsProvider

        init(injector: Injector) {
            postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
            commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
            commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
            replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
            blockedUserIdsProvider = injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider)
        }

        func getFeedItems(ids: [FeedItemInfoData]) async throws -> [Post] {
            let featuredChildByPostId: [String: String] = Dictionary(ids.compactMap {
                guard let featuredChildId = $0.featuredChildId else { return nil }
                return ($0.itemId, featuredChildId)
            }, uniquingKeysWith: { first, _ in first })
            let featuredComments = try await commentsDatabase.getComments(ids: ids.compactMap { $0.featuredChildId })
            return try await postsDatabase.getPosts(ids: ids.map { $0.itemId })
                .compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIdsProvider.blockedUserIds) else { return nil }
                    let featuredComment: Comment? = if let featuredCommentId = featuredChildByPostId[$0.uuid],
                                                       let storableComment = featuredComments.first(where: { $0.uuid == featuredCommentId }) {
                        Comment(storableComment: storableComment, replyFeedsStore: replyFeedsStore)
                    } else { nil }
                    return Post(storablePost: $0, commentFeedsStore: commentFeedsStore,
                                featuredComment: featuredComment)
                }
        }

        func upsert(feedItems: [Post]) async throws {
            try await postsDatabase.upsert(posts: feedItems.map { StorablePost(from: $0) })
        }

        func getMissingFeedItems(infos: [FeedItemInfo]) async throws -> [String] {
            try await postsDatabase.getMissingPosts(infos: infos)
        }

        func feedItemsPublisher(ids: [FeedItemInfoData]) throws -> AnyPublisher<[Post], any Error> {
            let featuredChildByPostId: [String: String] = Dictionary(ids.compactMap {
                guard let featuredChildId = $0.featuredChildId else { return nil }
                return ($0.itemId, featuredChildId)
            }, uniquingKeysWith: { first, _ in first })
            return Publishers.CombineLatest3(
                postsDatabase.postsPublisher(ids: ids.map { $0.itemId }),
                commentsDatabase.commentsPublisher(ids: ids.compactMap { $0.featuredChildId }),
                blockedUserIdsProvider.blockedUserIdsPublisher.setFailureType(to: Error.self)
            )
            .map { [commentFeedsStore, replyFeedsStore] posts, featuredComments, blockedUserIds in
                posts.compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIds) else { return nil }
                    let featuredComment: Comment? = if let featuredCommentId = featuredChildByPostId[$0.uuid],
                                                       let storableComment = featuredComments.first(where: { $0.uuid == featuredCommentId }) {
                        Comment(storableComment: storableComment, replyFeedsStore: replyFeedsStore)
                    } else { nil }
                    return Post(storablePost: $0, commentFeedsStore: commentFeedsStore,
                                featuredComment: featuredComment)
                }
            }
            .eraseToAnyPublisher()
        }

        func deleteAll(except ids: [String]) async throws {
            try await postsDatabase.deleteAll(except: ids)
        }
    }
    static func factory(injector: Injector) -> FeedManager<Post, Comment> {
        let commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
        let replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
        return FeedManager<Post, Comment>(
            injector: injector,
            feedItemDatabase: ProxyFeedItemDatabase(injector: injector),
            childFeedItemDatabase: CommentsFeedManager.ProxyFeedItemDatabase(injector: injector),
            getOptions: .all,
            mapper: { octoObject, aggregate, userInteraction in
                guard let storablePost = StorablePost(octoPost: octoObject, aggregate: aggregate,
                                                      userInteraction: userInteraction) else {
                    return nil
                }
                return Post(storablePost: storablePost, commentFeedsStore: commentFeedsStore, featuredComment: nil)
            },
            childMapper: { octoObject, aggregate, userInteraction in
                guard let storableComment = StorableComment(octoComment: octoObject, aggregate: aggregate,
                                                            userInteraction: userInteraction) else {
                    return nil
                }
                return Comment(storableComment: storableComment, replyFeedsStore: replyFeedsStore)
            })
    }
}

extension Post: FeedItem {
    public var id: String { uuid }
}

enum CommentsFeedManager {
    class ProxyFeedItemDatabase: FeedItemsDatabase {
        typealias FeedItem = Comment

        private let commentsDatabase: CommentsDatabase
        private let replyFeedsStore: ReplyFeedsStore
        private let blockedUserIdsProvider: BlockedUserIdsProvider
        init(injector: Injector) {
            commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
            replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
            blockedUserIdsProvider = injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider)
        }

        func getFeedItems(ids: [FeedItemInfoData]) async throws -> [Comment] {
            try await commentsDatabase.getComments(ids: ids.map { $0.itemId })
                .compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIdsProvider.blockedUserIds) else { return nil }
                    return Comment(storableComment: $0, replyFeedsStore: replyFeedsStore)
                }
        }

        func upsert(feedItems: [Comment]) async throws {
            try await commentsDatabase.upsert(comments: feedItems.map { StorableComment(from: $0) })
        }

        func getMissingFeedItems(infos: [FeedItemInfo]) async throws -> [String] {
            try await commentsDatabase.getMissingComments(infos: infos)
        }

        func feedItemsPublisher(ids: [FeedItemInfoData]) throws -> AnyPublisher<[Comment], any Error> {
            Publishers.CombineLatest(
                commentsDatabase.commentsPublisher(ids: ids.map { $0.itemId }),
                blockedUserIdsProvider.blockedUserIdsPublisher.setFailureType(to: Error.self)
            )
            .map { [replyFeedsStore] comments, blockedUserIds in
                comments.compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIds) else { return nil }
                    return Comment(storableComment: $0, replyFeedsStore: replyFeedsStore)
                }
            }
            .eraseToAnyPublisher()
        }

        func deleteAll(except ids: [String]) async throws {
            try await commentsDatabase.deleteAll(except: ids)
        }
    }
    static func factory(injector: Injector) -> FeedManager<Comment, Never> {
        let replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
        return FeedManager<Comment, Never>(
            injector: injector,
            feedItemDatabase: ProxyFeedItemDatabase(injector: injector),
            childFeedItemDatabase: nil,
            getOptions: .all,
            mapper: { octoObject, aggregate, userInteraction in
                guard let storableComment = StorableComment(octoComment: octoObject, aggregate: aggregate,
                                                            userInteraction: userInteraction) else {
                    return nil
                }
                return Comment(storableComment: storableComment, replyFeedsStore: replyFeedsStore)
            }, childMapper: nil)
    }
}

extension Comment: FeedItem {
    public var id: String { uuid }
}

enum RepliesFeedManager {
    private class ProxyFeedItemDatabase: FeedItemsDatabase {
        typealias FeedItem = Reply

        let repliesDatabase: RepliesDatabase
        private let blockedUserIdsProvider: BlockedUserIdsProvider

        init(injector: Injector) {
            repliesDatabase = injector.getInjected(identifiedBy: Injected.repliesDatabase)
            blockedUserIdsProvider = injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider)
        }

        func getFeedItems(ids: [FeedItemInfoData]) async throws -> [Reply] {
            try await repliesDatabase.getReplies(ids: ids.map { $0.itemId })
                .compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIdsProvider.blockedUserIds) else { return nil }
                    return Reply(storableComment: $0)
                }
        }

        func upsert(feedItems: [Reply]) async throws {
            try await repliesDatabase.upsert(replies: feedItems.map { StorableReply(from: $0) })
        }

        func getMissingFeedItems(infos: [FeedItemInfo]) async throws -> [String] {
            try await repliesDatabase.getMissingReplies(infos: infos)
        }

        func feedItemsPublisher(ids: [FeedItemInfoData]) throws -> AnyPublisher<[Reply], any Error> {
            Publishers.CombineLatest(
                repliesDatabase.repliesPublisher(ids: ids.map { $0.itemId }),
                blockedUserIdsProvider.blockedUserIdsPublisher.setFailureType(to: Error.self)
            )
            .map { replies, blockedUserIds in
                replies.compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIds) else { return nil }
                    return Reply(storableComment: $0)
                }
            }
            .eraseToAnyPublisher()
        }

        func deleteAll(except ids: [String]) async throws {
            try await repliesDatabase.deleteAll(except: ids)
        }
    }
    static func factory(injector: Injector) -> FeedManager<Reply, Never> {
        return FeedManager<Reply, Never>(
            injector: injector,
            feedItemDatabase: ProxyFeedItemDatabase(injector: injector),
            childFeedItemDatabase: nil,
            getOptions: .all,
            mapper: { octoObject, aggregate, userInteraction in
                guard let storableReply = StorableReply(octoReply: octoObject, aggregate: aggregate,
                                                        userInteraction: userInteraction) else {
                    return nil
                }
                return Reply(storableComment: storableReply)
            }, childMapper: nil)
    }
}

extension Reply: FeedItem {
    public var id: String { uuid }
}
