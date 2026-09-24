//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import OctopusRemoteClient
import OctopusDependencyInjection

extension Injected {
    static let userCommentsRepository = Injector.InjectedIdentifier<UserCommentsRepository>()
}

/// One page of the profile "Comments" feed.
public struct UserCommentsPage: Sendable {
    public let comments: [UserComment]
    /// Cursor for the next page, or `nil` when the feed is exhausted. **An empty `comments` with a
    /// non-nil cursor is not the end** — under heavy server-side ACL filtering a page can be short/empty
    /// yet more items remain; keep paging until the cursor is `nil`.
    public let nextPageCursor: String?
}

/// Fetches a member's authored comments & replies (the profile "Comments" tab) via the
/// `WithOctoObject` feed, mapping each item onto a `UserComment` with its parent context.
///
/// Pagination is caller-driven (the view model loops `firstPage` → `nextPage` until the cursor is nil).
/// The feed itself is not cached (each page is fetched fresh), but every octo object it ships — the
/// authored comments/replies and their parent posts/comments — is upserted into the shared content
/// databases so the UI can observe live measures and react in place. The upsert carries no
/// `RequesterCtx` (the `WithOctoObject` response omits it), so it never overwrites an existing user
/// reaction — `OctoObjectEntity.fill` only writes user interactions when they are non-nil.
///
/// Access control is enforced server-side: reading another member's feed throws when the community has
/// not enabled `showCommentsOnOtherProfiles` (surfaced as a `serverError`; the UI treats it as "hide the
/// tab", not a failure), and items whose parent was deleted / is in an inaccessible group are dropped
/// before they reach us.
public class UserCommentsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.userCommentsRepository

    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
    private let commentFeedsStore: CommentFeedsStore
    private let replyFeedsStore: ReplyFeedsStore
    private let postsDatabase: PostsDatabase
    private let commentsDatabase: CommentsDatabase
    private let repliesDatabase: RepliesDatabase

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
        replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
        postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
        repliesDatabase = injector.getInjected(identifiedBy: Injected.repliesDatabase)
    }

    /// Fetches the first page. `feedId` is `Profile.descCommentFeedId` / `CurrentUserProfile.descCommentFeedId`.
    public func firstPage(feedId: String, pageSize: Int = 20) async throws(ServerCallError) -> UserCommentsPage {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.feedService.initializeFeedWithOctoObject(
                feedId: feedId, pageSize: Int32(pageSize),
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            await persist(response)
            return page(from: response)
        } catch {
            throw Self.mapError(error)
        }
    }

    /// Fetches the page after `pageCursor` (from a previous page's `nextPageCursor`).
    public func nextPage(pageCursor: String, pageSize: Int = 20) async throws(ServerCallError) -> UserCommentsPage {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.feedService.getFeedWithOctoObjectPage(
                pageCursor: pageCursor, pageSize: Int32(pageSize), fetchAggregates: true,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            await persist(response)
            return page(from: response)
        } catch {
            throw Self.mapError(error)
        }
    }

    private func page(from response: Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse) -> UserCommentsPage {
        UserCommentsPage(
            comments: UserComment.list(from: response, commentFeedsStore: commentFeedsStore,
                                       replyFeedsStore: replyFeedsStore),
            nextPageCursor: response.nextPageCursor.nilIfEmpty)
    }

    /// Upserts every octo object carried by the page (authored comments/replies + their parent
    /// posts/comments) into the shared content databases, so the UI can observe their live measures and
    /// react in place. Classifies by content oneof (comment/reply first, then post — a non-published
    /// `StorablePost` init also succeeds for responses, so posts must be tried last). Deduplicated by
    /// uuid to avoid inserting the same entity twice in a single `upsert` batch.
    private func persist(_ response: Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse) async {
        let aggregatesById = Dictionary(
            (response.aggregates + response.relatedAggregates).map { ($0.itemID, $0.aggregate) },
            uniquingKeysWith: { first, _ in first })

        var posts: [String: StorablePost] = [:]
        var comments: [String: StorableComment] = [:]
        var replies: [String: StorableReply] = [:]
        for octo in response.feed + response.relatedObjects {
            let aggregate = aggregatesById[octo.id]
            if octo.content.hasComment {
                comments[octo.id] = StorableComment(octoComment: octo, aggregate: aggregate, userInteraction: nil)
            } else if octo.content.hasReply {
                replies[octo.id] = StorableReply(octoReply: octo, aggregate: aggregate, userInteraction: nil)
            } else if let post = StorablePost(octoPost: octo, aggregate: aggregate, userInteraction: nil) {
                posts[octo.id] = post
            }
        }

        try? await postsDatabase.upsert(posts: Array(posts.values))
        try? await commentsDatabase.upsert(comments: Array(comments.values))
        try? await repliesDatabase.upsert(replies: Array(replies.values))
    }

    private static func mapError(_ error: Error) -> ServerCallError {
        if let error = error as? RemoteClientError {
            return .serverError(ServerError(remoteClientError: error))
        }
        return .other(error)
    }
}
