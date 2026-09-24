//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import Foundation
import OctopusGrpcModels
@testable import OctopusCore

/// Parent-context resolution of the profile "Comments" feed (OCT-1067) — the `parentId` walk and the
/// orphan-skipping the backend spec calls out. Pure logic, no I/O.
struct UserCommentsResolverTests {
    typealias OctoObject = Com_Octopuscommunity_OctoObject

    private func post(_ id: String) -> OctoObject {
        .with { $0.id = id; $0.content = .with { $0.post = .init() } }
    }
    private func comment(_ id: String, on parentId: String) -> OctoObject {
        .with { $0.id = id; $0.parentID = parentId; $0.content = .with { $0.comment = .init() } }
    }
    private func reply(_ id: String, on parentId: String) -> OctoObject {
        .with { $0.id = id; $0.parentID = parentId; $0.content = .with { $0.reply = .init() } }
    }

    @Test func commentResolvesToItsParentPost() {
        let result = UserCommentsResolver.resolve(
            feed: [comment("c1", on: "p1")],
            relatedObjects: [post("p1")])

        #expect(result == [.comment(item: comment("c1", on: "p1"), post: post("p1"))])
    }

    @Test func replyResolvesToParentCommentAndGrandparentPost() {
        let result = UserCommentsResolver.resolve(
            feed: [reply("r1", on: "c1")],
            relatedObjects: [comment("c1", on: "p1"), post("p1")])

        #expect(result == [.reply(item: reply("r1", on: "c1"),
                                  comment: comment("c1", on: "p1"),
                                  post: post("p1"))])
    }

    @Test func replyKeptEvenWhenGrandparentPostMissing() {
        // Parent comment present, grandparent post not shipped ⇒ reply still shown, post = nil.
        let result = UserCommentsResolver.resolve(
            feed: [reply("r1", on: "c1")],
            relatedObjects: [comment("c1", on: "p1")])

        #expect(result == [.reply(item: reply("r1", on: "c1"),
                                  comment: comment("c1", on: "p1"),
                                  post: nil)])
    }

    @Test func orphanCommentIsSkipped() {
        // Parent post gone (deleted / inaccessible group) ⇒ don't render an orphan.
        #expect(UserCommentsResolver.resolve(feed: [comment("c1", on: "p1")], relatedObjects: []).isEmpty)
    }

    @Test func orphanReplyIsSkipped() {
        // Parent comment missing ⇒ skip.
        #expect(UserCommentsResolver.resolve(feed: [reply("r1", on: "c1")], relatedObjects: []).isEmpty)
    }

    @Test func nonCommentOrReplyItemIsDropped() {
        // userComments only yields comments & replies; anything else is ignored.
        #expect(UserCommentsResolver.resolve(feed: [post("p1")], relatedObjects: []).isEmpty)
    }

    @Test func parentCanBeAnotherFeedItemNotOnlyInRelatedObjects() {
        // A reply whose parent comment is itself in this page's feed (not relatedObjects) still resolves.
        let result = UserCommentsResolver.resolve(
            feed: [comment("c1", on: "p1"), reply("r1", on: "c1")],
            relatedObjects: [post("p1")])

        #expect(result.count == 2)
        #expect(result[0] == .comment(item: comment("c1", on: "p1"), post: post("p1")))
        #expect(result[1] == .reply(item: reply("r1", on: "c1"),
                                    comment: comment("c1", on: "p1"), post: post("p1")))
    }

    @Test func feedOrderIsPreservedAndOrphansDroppedInPlace() {
        // Mixed page: valid comment, orphan comment (dropped), valid reply — order of survivors kept.
        let result = UserCommentsResolver.resolve(
            feed: [comment("c1", on: "p1"), comment("cX", on: "pGone"), reply("r1", on: "c1")],
            relatedObjects: [post("p1")])

        #expect(result.map(\.item.id) == ["c1", "r1"])
    }
}
