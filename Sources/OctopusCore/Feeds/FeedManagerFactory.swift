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
        private let commentFeedsStore: CommentFeedsStore
        private let blockedUserIdsProvider: BlockedUserIdsProvider

        init(injector: Injector) {
            postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
            commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
            blockedUserIdsProvider = injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider)
        }

        func getFeedItems(ids: [String]) async throws -> [Post] {
            try await postsDatabase.getPosts(ids: ids)
                .compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIdsProvider.blockedUserIds) else { return nil }
                    return Post(storablePost: $0, commentFeedsStore: commentFeedsStore)
                }
        }

        func upsert(feedItems: [Post]) async throws {
            try await postsDatabase.upsert(posts: feedItems.map { StorablePost(from: $0) })
        }

        func getMissingFeedItems(infos: [FeedItemInfo]) async throws -> [String] {
            try await postsDatabase.getMissingPosts(infos: infos)
        }

        func feedItemsPublisher(ids: [String]) throws -> AnyPublisher<[Post], any Error> {
            Publishers.CombineLatest(
                postsDatabase.postsPublisher(ids: ids),
                blockedUserIdsProvider.blockedUserIdsPublisher.setFailureType(to: Error.self)
            )
            .map { [commentFeedsStore] posts, blockedUserIds in
                posts.compactMap {
                    guard !$0.author.isBlocked(in: blockedUserIds) else { return nil }
                    return Post(storablePost: $0, commentFeedsStore: commentFeedsStore)
                }
            }
            .eraseToAnyPublisher()
        }

        func deleteAll(except ids: [String]) async throws {
            try await postsDatabase.deleteAll(except: ids)
        }
    }
    static func factory(injector: Injector) -> FeedManager<Post> {
        let commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
        return FeedManager<Post>(
            injector: injector,
            feedItemDatabase: ProxyFeedItemDatabase(injector: injector),
            getOptions: .all,
            mapper: { octoObject, aggregate, userInteraction in
                guard let storablePost = StorablePost(octoPost: octoObject, aggregate: aggregate,
                                                      userInteraction: userInteraction) else {
                    return nil
                }
                return Post(storablePost: storablePost, commentFeedsStore: commentFeedsStore)
            })
    }
}

extension Post: FeedItem {
    public var id: String { uuid }
}

enum CommentsFeedManager {
    private class ProxyFeedItemDatabase: FeedItemsDatabase {
        typealias FeedItem = Comment

        private let commentsDatabase: CommentsDatabase
        private let replyFeedsStore: ReplyFeedsStore
        private let blockedUserIdsProvider: BlockedUserIdsProvider
        init(injector: Injector) {
            commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
            replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
            blockedUserIdsProvider = injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider)
        }

        func getFeedItems(ids: [String]) async throws -> [Comment] {
            try await commentsDatabase.getComments(ids: ids)
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

        func feedItemsPublisher(ids: [String]) throws -> AnyPublisher<[Comment], any Error> {
            Publishers.CombineLatest(
                commentsDatabase.commentsPublisher(ids: ids),
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
    static func factory(injector: Injector) -> FeedManager<Comment> {
        let replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
        return FeedManager<Comment>(
            injector: injector,
            feedItemDatabase: ProxyFeedItemDatabase(injector: injector),
            getOptions: .all,
            mapper: { octoObject, aggregate, userInteraction in
                guard let storableComment = StorableComment(octoComment: octoObject, aggregate: aggregate,
                                                            userInteraction: userInteraction) else {
                    return nil
                }
                return Comment(storableComment: storableComment, replyFeedsStore: replyFeedsStore)
            })
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

        func getFeedItems(ids: [String]) async throws -> [Reply] {
            try await repliesDatabase.getReplies(ids: ids)
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

        func feedItemsPublisher(ids: [String]) throws -> AnyPublisher<[Reply], any Error> {
            Publishers.CombineLatest(
                repliesDatabase.repliesPublisher(ids: ids),
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
    static func factory(injector: Injector) -> FeedManager<Reply> {
        return FeedManager<Reply>(
            injector: injector,
            feedItemDatabase: ProxyFeedItemDatabase(injector: injector),
            getOptions: .all,
            mapper: { octoObject, aggregate, userInteraction in
                guard let storableReply = StorableReply(octoReply: octoObject, aggregate: aggregate,
                                                        userInteraction: userInteraction) else {
                    return nil
                }
                return Reply(storableComment: storableReply)
            })
    }
}

extension Reply: FeedItem {
    public var id: String { uuid }
}
