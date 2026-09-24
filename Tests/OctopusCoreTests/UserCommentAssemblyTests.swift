//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import Foundation
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// Assembly of the profile "Comments" feed (OCT-1067): `UserComment.list` mapping a `WithOctoObject`
/// response onto the domain models — parent/grandparent wiring, aggregate correlation, and the
/// defensive skip of items that can't be anchored. The pure parent-context walk is covered separately
/// in `UserCommentsResolverTests`.
struct UserCommentAssemblyTests {
    typealias OctoObject = Com_Octopuscommunity_OctoObject
    typealias Response = Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse

    private let commentFeedsStore: CommentFeedsStore
    private let replyFeedsStore: ReplyFeedsStore

    init() {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .blockedUserIdsProvider)
        commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
        replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
    }

    // MARK: - Octo-object builders (mirror UserCommentsResolverTests)

    private func post(_ id: String) -> OctoObject {
        .with { $0.id = id; $0.content = .with { $0.post = .init() } }
    }
    private func comment(_ id: String, on parentId: String) -> OctoObject {
        .with { $0.id = id; $0.parentID = parentId; $0.content = .with { $0.comment = .init() } }
    }
    private func reply(_ id: String, on parentId: String) -> OctoObject {
        .with { $0.id = id; $0.parentID = parentId; $0.content = .with { $0.reply = .init() } }
    }
    private func aggregate(_ itemId: String, children: Int) -> Com_Octopuscommunity_FeedAggregate {
        .with {
            $0.itemID = itemId
            $0.aggregate = .with { $0.childrenCount = UInt32(children); $0.reactions = []; $0.viewCount = 0 }
        }
    }

    private func list(feed: [OctoObject], related: [OctoObject],
                      aggregates: [Com_Octopuscommunity_FeedAggregate] = []) -> [UserComment] {
        let response = Response.with {
            $0.feed = feed
            $0.relatedObjects = related
            $0.aggregates = aggregates
        }
        return UserComment.list(from: response, commentFeedsStore: commentFeedsStore,
                                replyFeedsStore: replyFeedsStore)
    }

    // MARK: - Tests

    @Test func commentEntryWiresItsPostAndHasNoParent() {
        let result = list(feed: [comment("c1", on: "p1")], related: [post("p1")])

        #expect(result.count == 1)
        #expect(result[0].id == "c1")
        #expect(result[0].post?.uuid == "p1")
        #expect(result[0].parentComment == nil)
        guard case let .comment(comment) = result[0].content else {
            Issue.record("expected a .comment entry"); return
        }
        #expect(comment.uuid == "c1")
    }

    @Test func replyEntryWiresParentCommentAndGrandparentPost() {
        let result = list(feed: [reply("r1", on: "c1")], related: [comment("c1", on: "p1"), post("p1")])

        #expect(result.count == 1)
        #expect(result[0].id == "r1")
        #expect(result[0].parentComment?.uuid == "c1")
        #expect(result[0].post?.uuid == "p1")
        guard case let .reply(reply) = result[0].content else {
            Issue.record("expected a .reply entry"); return
        }
        #expect(reply.uuid == "r1")
    }

    @Test func replyIsKeptWhenGrandparentPostMissing() {
        // Parent comment shipped, grandparent post not: the reply is still shown, with `post == nil`.
        let result = list(feed: [reply("r1", on: "c1")], related: [comment("c1", on: "p1")])

        #expect(result.count == 1)
        #expect(result[0].parentComment?.uuid == "c1")
        #expect(result[0].post == nil)
    }

    @Test func orphanCommentIsSkippedDuringAssembly() {
        // Parent post gone ⇒ resolver drops it ⇒ no entry produced (defensive compactMap).
        #expect(list(feed: [comment("c1", on: "p1")], related: []).isEmpty)
    }

    @Test func aggregatesAreCorrelatedByItemId() {
        let result = list(feed: [comment("c1", on: "p1")], related: [post("p1")],
                          aggregates: [aggregate("c1", children: 7)])

        #expect(result.count == 1)
        guard case let .comment(comment) = result[0].content else {
            Issue.record("expected a .comment entry"); return
        }
        #expect(comment.aggregatedInfo.childCount == 7)
    }

    @Test func feedOrderIsPreservedAndOrphansDroppedInPlace() {
        let result = list(
            feed: [comment("c1", on: "p1"), comment("cX", on: "pGone"), reply("r1", on: "c1")],
            related: [post("p1")])

        #expect(result.map(\.id) == ["c1", "r1"])
    }
}
